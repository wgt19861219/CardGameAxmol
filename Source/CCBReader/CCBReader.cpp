#include "CCBReader.h"
#include "CCNodeLoader.h"
#include "CCNodeLoaderLibrary.h"
#include "CCData.h"
#include "CCBValue.h"
#include "CCBKeyframe.h"
#include "CCBSequence.h"
#include "CCBSequenceProperty.h"
#include "CCBAnimationManager.h"

#include <algorithm>
#include <cstring>

using namespace ax;
using namespace std;

namespace ccb {

// ===== CCBFile =====

CCBFile::CCBFile() = default;

CCBFile* CCBFile::create()
{
    auto* ret = new CCBFile();
    ret->autorelease();
    return ret;
}

void CCBFile::setCCBFileNode(ax::Node* pNode)
{
    AX_SAFE_RELEASE(mCCBFileNode);
    mCCBFileNode = pNode;
    AX_SAFE_RETAIN(mCCBFileNode);
}

// ===== CCBReader =====

static float sCCBResolutionScale = 1.0f;

CCBReader::CCBReader(CCNodeLoaderLibrary* pLibrary,
                     CCBMemberVariableAssigner* pAssigner,
                     CCBSelectorResolver* pResolver)
    : mCCNodeLoaderLibrary(pLibrary)
    , mCCBMemberVariableAssigner(pAssigner)
    , mCCBSelectorResolver(pResolver)
{
    AX_SAFE_RETAIN(mCCNodeLoaderLibrary);
    init();
}

CCBReader::CCBReader(CCBReader* pReader)
    : mCCNodeLoaderLibrary(pReader->mCCNodeLoaderLibrary)
    , mCCBMemberVariableAssigner(pReader->mCCBMemberVariableAssigner)
    , mCCBSelectorResolver(pReader->mCCBSelectorResolver)
    , mLoadedSpriteSheets(pReader->mLoadedSpriteSheets)
    , mCCBRootPath(pReader->getCCBRootPath())
    , mCCBFilePath(pReader->getCCBFilePath())
    , mOwnerOutletNames(pReader->mOwnerOutletNames)
    , mOwnerCallbackNames(pReader->mOwnerCallbackNames)
{
    AX_SAFE_RETAIN(mCCNodeLoaderLibrary);
    mOwnerOutletNodes = pReader->mOwnerOutletNodes;
    mOwnerCallbackNodes = pReader->mOwnerCallbackNodes;
    init();
}

CCBReader::~CCBReader()
{
    AX_SAFE_RELEASE_NULL(mOwner);
    AX_SAFE_RELEASE_NULL(mData);
    AX_SAFE_RELEASE(mCCNodeLoaderLibrary);
    mStringCache.clear();
    setAnimationManager(nullptr);
}

bool CCBReader::init()
{
    auto* pActionManager = CCBAnimationManager::create();
    setAnimationManager(pActionManager);
    mActionManager->setRootContainerSize(Director::getInstance()->getVisibleSize());
    return true;
}

void CCBReader::setCCBRootPath(const char* pPath)
{
    AXASSERT(pPath != nullptr, "");
    mCCBRootPath = pPath;
}

void CCBReader::setCCBFilePath(const char* pPath)
{
    AXASSERT(pPath != nullptr, "");
    mCCBFilePath = pPath;
}

// ===== 文件读取入口 =====

ax::Node* CCBReader::readNodeGraphFromFile(const char* pCCBFileName)
{
    return readNodeGraphFromFile(pCCBFileName, nullptr);
}

ax::Node* CCBReader::readNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner)
{
    return readNodeGraphFromFile(pCCBFileName, pOwner, Director::getInstance()->getVisibleSize());
}

ax::Node* CCBReader::readNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner, const ax::Size& parentSize)
{
    if (!pCCBFileName || strlen(pCCBFileName) == 0)
        return nullptr;

    std::string strCCBFileName(pCCBFileName);
    mCCBName = strCCBFileName;

    // 读取文件数据
    std::string fullPath = FileUtils::getInstance()->fullPathForFilename(strCCBFileName);
    if (fullPath.empty())
    {
        AXLOGW("CCBReader: file not found: {}", strCCBFileName);
        return nullptr;
    }

    auto data = FileUtils::getInstance()->getDataFromFile(fullPath);
    if (data.isNull())
    {
        AXLOGW("CCBReader: failed to read: {}", fullPath);
        return nullptr;
    }

    CCData* ccData = new CCData(data.getBytes(), data.getSize());

    ax::Node* ret = readNodeGraphFromData(ccData, pOwner, parentSize);
    ccData->release();

    return ret;
}

ax::Node* CCBReader::readNodeGraphFromData(CCData* pData, ax::Object* pOwner, const ax::Size& parentSize)
{
    mData = pData;
    AX_SAFE_RETAIN(mData);
    mBytes = mData->getBytes();
    mDataSize = mData->getSize();
    mCurrentByte = 0;
    mCurrentBit = 0;
    mOwner = pOwner;
    AX_SAFE_RETAIN(mOwner);

    mActionManager->setRootContainerSize(parentSize);

    ax::Node* pNodeGraph = readFileWithCleanUp(true);

    if (pNodeGraph && mActionManager->getAutoPlaySequenceId() != -1 && !jsControlled)
    {
        mActionManager->runAnimationsForSequenceIdTweenDuration(mActionManager->getAutoPlaySequenceId(), 0);
    }

    return pNodeGraph;
}

ax::Scene* CCBReader::createSceneWithNodeGraphFromFile(const char* pCCBFileName)
{
    return createSceneWithNodeGraphFromFile(pCCBFileName, nullptr);
}

ax::Scene* CCBReader::createSceneWithNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner)
{
    return createSceneWithNodeGraphFromFile(pCCBFileName, pOwner, Director::getInstance()->getVisibleSize());
}

ax::Scene* CCBReader::createSceneWithNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner, const ax::Size& parentSize)
{
    ax::Node* pNode = readNodeGraphFromFile(pCCBFileName, pOwner, parentSize);
    auto* pScene = ax::Scene::create();
    if (pNode)
        pScene->addChild(pNode);
    return pScene;
}

// ===== 核心解析流程 =====

ax::Node* CCBReader::readFileWithCleanUp(bool bCleanUp)
{
    if (!readHeader())
        return nullptr;

    if (!readStringCache())
        return nullptr;

    if (!readSequences())
        return nullptr;

    ax::Node* pNode = readNodeGraph(nullptr);

    if (!pNode)
        return nullptr;

    if (!mActionManager->getRootNode())
        mActionManager->setRootNode(pNode);

    if (bCleanUp)
        cleanUpNodeGraph(pNode);

    return pNode;
}

bool CCBReader::readHeader()
{
    if (!mBytes || mDataSize < 4)
        return false;

    // 读取魔术字节 "ccbi"
    int magicBytes = *((int*)(mBytes + mCurrentByte));
    mCurrentByte += 4;

    char magic[5] = {};
    memcpy(magic, &magicBytes, 4);
    if (memcmp(magic, "ccbi", 4) != 0)
    {
        AXLOGW("CCBReader: invalid magic bytes, not a CCBI file");
        return false;
    }

    // 读取版本号
    int version = readInt(false);
    if (version != kCCBVersion)
    {
        AXLOGW("CCBReader: incompatible version (file: {}, reader: {})", version, kCCBVersion);
        return false;
    }

    // JS 控制标志
    jsControlled = readBool();
    mActionManager->jsControlled = jsControlled;

    return true;
}

bool CCBReader::readStringCache()
{
    int numStrings = readInt(false);
    for (int i = 0; i < numStrings; i++)
    {
        mStringCache.push_back(readUTF8());
    }
    return true;
}

bool CCBReader::readSequences()
{
    auto& sequences = mActionManager->getSequences();

    int numSeqs = readInt(false);
    for (int i = 0; i < numSeqs; i++)
    {
        auto* seq = CCBSequence::create();
        seq->setDuration(readFloat());
        std::string name = readCachedString();
        seq->setName(name.c_str());
        seq->setSequenceId(readInt(false));
        seq->setChainedSequenceId(readInt(true));

        readCallbackKeyframesForSeq(seq);
        readSoundKeyframesForSeq(seq);

        sequences.pushBack(seq);
    }

    mActionManager->setAutoPlaySequenceId(readInt(true));
    return true;
}

ax::Node* CCBReader::readNodeGraph(ax::Node* pParent)
{
    // 读取类名
    std::string className = readCachedString();

    std::string jsControlledName;
    if (jsControlled)
        jsControlledName = readCachedString();

    // 读取成员变量赋值类型和名称
    int memberVarAssignmentType = readInt(false);
    std::string memberVarAssignmentName;
    if (memberVarAssignmentType != 0)
    {
        memberVarAssignmentName = readCachedString();
    }

    // 获取加载器
    CCNodeLoader* ccNodeLoader = mCCNodeLoaderLibrary->getCCNodeLoader(className);
    if (!ccNodeLoader)
    {
        AXLOGW("CCBReader: no loader for class '{}'", className);
        return nullptr;
    }

    // 加载节点
    ax::Node* node = ccNodeLoader->loadCCNode(pParent, this);
    if (!node)
    {
        AXLOGW("CCBReader: failed to create node for class '{}'", className);
        return nullptr;
    }

    // 设置根节点
    if (!mActionManager->getRootNode())
        mActionManager->setRootNode(node);

    // 读取动画属性
    mAnimatedProps.clear();

    int numSequence = readInt(false);
    for (int i = 0; i < numSequence; ++i)
    {
        int seqId = readInt(false);
        int numProps = readInt(false);

        for (int j = 0; j < numProps; ++j)
        {
            auto* seqProp = CCBSequenceProperty::create();
            seqProp->setName(readCachedString().c_str());
            seqProp->setType(readInt(false));
            mAnimatedProps.insert(seqProp->getName());

            int numKeyframes = readInt(false);
            for (int k = 0; k < numKeyframes; ++k)
            {
                CCBKeyframe* keyframe = readKeyframe(seqProp->getType());
                seqProp->getKeyframes().pushBack(keyframe);
            }
        }
    }

    // 处理成员变量赋值
    if (memberVarAssignmentType != 0)
    {
        ax::Object* target = nullptr;
        if (memberVarAssignmentType == 1)
            target = mActionManager->getRootNode();
        else if (memberVarAssignmentType == 2)
            target = mOwner;

        if (target && mCCBMemberVariableAssigner)
        {
            mCCBMemberVariableAssigner->onAssignCCBMemberVariable(target, memberVarAssignmentName.c_str(), node);
        }
    }

    // 读取子节点
    int numChildren = readInt(false);
    for (int i = 0; i < numChildren; i++)
    {
        ax::Node* child = readNodeGraph(node);
        if (child)
            node->addChild(child);
    }

    return node;
}

CCBKeyframe* CCBReader::readKeyframe(int type)
{
    auto* keyframe = CCBKeyframe::create();
    keyframe->setTime(readFloat());

    int easingType = readInt(false);
    float easingOpt = 0;

    if (easingType >= 3)
    {
        easingOpt = readFloat();
    }
    keyframe->setEasingType(easingType);
    keyframe->setEasingOpt(easingOpt);

    ax::Object* value = nullptr;

    if (type == kCCBPropTypeCheck)
    {
        value = CCBValue::create(readBool());
    }
    else if (type == kCCBPropTypeByte)
    {
        value = CCBValue::create(readByte());
    }
    else if (type == kCCBPropTypeColor3)
    {
        int r = readByte();
        int g = readByte();
        int b = readByte();
        value = ccColor3BWapper::create(Color32(r, g, b, 255));
    }
    else if (type == kCCBPropTypeDegrees || type == kCCBPropTypeFloat || type == kCCBPropTypeFloatVar)
    {
        value = CCBValue::create(readFloat());
    }
    else if (type == kCCBPropTypeScaleLock || type == kCCBPropTypePosition || type == kCCBPropTypeFloatXY)
    {
        float a = readFloat();
        float b = readFloat();
        auto* arr = new ax::Vector<ax::Object*>();
        arr->pushBack(CCBValue::create(a));
        arr->pushBack(CCBValue::create(b));
        value = CCBValue::create(arr);
    }
    else if (type == kCCBPropTypeSpriteFrame)
    {
        std::string spriteSheet = readCachedString();
        std::string spriteFile = readCachedString();

        SpriteFrame* spriteFrame = nullptr;
        if (spriteSheet.empty())
        {
            spriteFile = mCCBRootPath + spriteFile;
            spriteFrame = SpriteFrameCache::getInstance()->getSpriteFrameByName(spriteFile);
            if (!spriteFrame)
            {
                Texture2D* texture = Director::getInstance()->getTextureCache()->addImage(spriteFile);
                if (texture)
                {
                    Rect bounds(0, 0, texture->getContentSize().width, texture->getContentSize().height);
                    spriteFrame = SpriteFrame::createWithTexture(texture, bounds);
                }
            }
        }
        else
        {
            spriteSheet = mCCBRootPath + spriteSheet;
            auto* frameCache = SpriteFrameCache::getInstance();
            if (mLoadedSpriteSheets.find(spriteSheet) == mLoadedSpriteSheets.end())
            {
                frameCache->addSpriteFramesWithFile(spriteSheet);
                mLoadedSpriteSheets.insert(spriteSheet);
            }
            spriteFrame = frameCache->getSpriteFrameByName(spriteFile);
        }
        value = spriteFrame;
    }

    if (value)
        keyframe->setValue(value);

    return keyframe;
}

bool CCBReader::readCallbackKeyframesForSeq(CCBSequence* seq)
{
    int numKeyframes = readInt(false);
    if (!numKeyframes) return true;

    auto* channel = CCBSequenceProperty::create();

    for (int i = 0; i < numKeyframes; ++i)
    {
        float time = readFloat();
        std::string callbackName = readCachedString();
        int callbackType = readInt(false);

        auto* keyframe = CCBKeyframe::create();
        keyframe->setTime(time);

        channel->getKeyframes().pushBack(keyframe);
    }

    seq->setCallbackChannel(channel);
    return true;
}

bool CCBReader::readSoundKeyframesForSeq(CCBSequence* seq)
{
    int numKeyframes = readInt(false);
    if (!numKeyframes) return true;

    auto* channel = CCBSequenceProperty::create();

    for (int i = 0; i < numKeyframes; ++i)
    {
        float time = readFloat();
        std::string soundFile = readCachedString();
        float pitch = readFloat();
        float pan = readFloat();
        float gain = readFloat();

        auto* keyframe = CCBKeyframe::create();
        keyframe->setTime(time);

        channel->getKeyframes().pushBack(keyframe);
    }

    seq->setSoundChannel(channel);
    return true;
}

// ===== 二进制读取方法 =====

bool CCBReader::getBit()
{
    if (mCurrentByte >= mDataSize) return false;
    bool bit;
    unsigned char byte = *(mBytes + mCurrentByte);
    bit = (byte & (1 << mCurrentBit)) != 0;

    mCurrentBit++;
    if (mCurrentBit >= 8)
    {
        mCurrentBit = 0;
        mCurrentByte++;
    }

    return bit;
}

void CCBReader::alignBits()
{
    if (mCurrentBit)
    {
        mCurrentBit = 0;
        mCurrentByte++;
    }
}

int CCBReader::readInt(bool pSigned)
{
    int numBits = 0;
    while (!getBit())
    {
        numBits++;
    }

    long long current = 0;
    for (int a = numBits - 1; a >= 0; a--)
    {
        if (getBit())
        {
            current |= 1LL << a;
        }
    }
    current |= 1LL << numBits;

    int num;
    if (pSigned)
    {
        int s = current % 2;
        if (s)
            num = (int)(current / 2);
        else
            num = (int)(-current / 2);
    }
    else
    {
        num = (int)(current - 1);
    }

    alignBits();
    return num;
}

unsigned char CCBReader::readByte()
{
    if (mCurrentByte >= mDataSize) return 0;
    unsigned char byte = mBytes[mCurrentByte];
    mCurrentByte++;
    return byte;
}

bool CCBReader::readBool()
{
    return readByte() != 0;
}

std::string CCBReader::readUTF8()
{
    int b0 = readByte();
    int b1 = readByte();
    int numBytes = b0 << 8 | b1;

    if (numBytes <= 0)
        return "";

    if (mCurrentByte + numBytes > mDataSize)
    {
        AXLOGW("CCBReader: readUTF8 out of bounds (need {}, have {})", numBytes, mDataSize - mCurrentByte);
        return "";
    }

    std::string ret((char*)(mBytes + mCurrentByte), numBytes);
    mCurrentByte += numBytes;
    return ret;
}

float CCBReader::readFloat()
{
    unsigned char type = readByte();

    switch (type)
    {
    case 0: return 0;
    case 1: return 1;
    case 2: return -1;
    case 3: return 0.5f;
    case 4: return (float)readInt(true);
    default:
    {
        if (mCurrentByte + sizeof(float) > mDataSize)
        {
            AXLOGW("CCBReader: readFloat out of bounds");
            return 0;
        }
        float f = 0;
        memcpy(&f, mBytes + mCurrentByte, sizeof(float));
        mCurrentByte += sizeof(float);
        return f;
    }
    }
}

std::string CCBReader::readCachedString()
{
    int n = readInt(false);
    if (n >= 0 && n < (int)mStringCache.size())
        return mStringCache[n];
    return "";
}

// ===== 工具方法 =====

void CCBReader::cleanUpNodeGraph(ax::Node* pNode)
{
    pNode->setUserObject(nullptr);
    for (auto& child : pNode->getChildren())
    {
        cleanUpNodeGraph(child);
    }
}

CCBAnimationManager* CCBReader::getAnimationManager()
{
    return mActionManager;
}

void CCBReader::setAnimationManager(CCBAnimationManager* pAnimationManager)
{
    AX_SAFE_RELEASE(mActionManager);
    mActionManager = pAnimationManager;
    AX_SAFE_RETAIN(mActionManager);
}

void CCBReader::addOwnerOutletName(const std::string& name)
{
    mOwnerOutletNames.push_back(name);
}

void CCBReader::addOwnerOutletNode(ax::Node* node)
{
    if (!node) return;
    mOwnerOutletNodes.pushBack(node);
}

void CCBReader::addOwnerCallbackName(const std::string& name)
{
    mOwnerCallbackNames.push_back(name);
}

void CCBReader::addOwnerCallbackNode(ax::Node* node)
{
    if (!node) return;
    mOwnerCallbackNodes.pushBack(node);
}

void CCBReader::addDocumentCallbackName(const std::string& name)
{
    mActionManager->addDocumentCallbackName(name);
}

void CCBReader::addDocumentCallbackNode(ax::Node* node)
{
    mActionManager->addDocumentCallbackNode(node);
}

float CCBReader::getResolutionScale()
{
    return Director::getInstance()->getContentScaleFactor();
}

void CCBReader::setResolutionScale(float scale)
{
    sCCBResolutionScale = scale;
}

std::string CCBReader::lastPathComponent(const char* pPath)
{
    std::string path(pPath);
    auto slashPos = path.find_last_of("/\\");
    if (slashPos != std::string::npos)
        return path.substr(slashPos + 1);
    return path;
}

std::string CCBReader::deletePathExtension(const char* pPath)
{
    std::string path(pPath);
    auto dotPos = path.find_last_of('.');
    if (dotPos != std::string::npos)
        return path.substr(0, dotPos);
    return path;
}

std::string CCBReader::toLowerCase(const char* pString)
{
    std::string copy(pString);
    std::transform(copy.begin(), copy.end(), copy.begin(), ::tolower);
    return copy;
}

bool CCBReader::endsWith(const char* pString, const char* pEnding)
{
    std::string str(pString);
    std::string ending(pEnding);
    if (str.length() >= ending.length())
        return str.compare(str.length() - ending.length(), ending.length(), ending) == 0;
    return false;
}

} // namespace ccb
