#include "CCBContainer.h"
#include "CCBReader/CCBReader.h"
#include "CCBReader/CCBAnimationManager.h"
#include "CCBReader/CCNodeLoaderLibrary.h"

#include <algorithm>
#include <cstring>

std::string CCBContainer::s_ccbFilePath = "";

CCBContainer::CCBContainer()
    : mActionManager(nullptr)
    , mCCBContainerListener(nullptr)
    , mCCBTag(0)
    , mScriptFunHandler(0)
    , mIndex(0)
{
}

CCBContainer::CCBContainer(CCBContainerListener* listener, int tag)
    : mActionManager(nullptr)
    , mCCBContainerListener(listener)
    , mCCBTag(tag)
    , mScriptFunHandler(0)
    , mIndex(0)
{
}

CCBContainer::~CCBContainer()
{
    unload();
}

bool CCBContainer::init()
{
    mCCBContainerListener = nullptr;
    mCCBTag = 0;
    mLoadedCCBFile = "";
    mScriptFunHandler = 0;
    return true;
}

void CCBContainer::setListener(CCBContainerListener* listener, int tag)
{
    mCCBContainerListener = listener;
    mCCBTag = tag;
}

void CCBContainer::setAllChildColor(unsigned char r, unsigned char g, unsigned char b)
{
    ax::Color32 c(r, g, b);
    for (auto& pair : mVariables)
    {
        auto* node = dynamic_cast<ax::Node*>(pair.second);
        if (node)
            node->setColor(c);
    }
}

void CCBContainer::loadCcbiFile(const std::string& filename, bool forceLoad)
{
    if (getLoaded())
    {
        if (forceLoad)
            unload();
        else
            return;
    }

    mLoadedCCBFile = filename;

    // 创建加载器库
    auto* ccNodeLoaderLibrary = ccb::CCNodeLoaderLibrary::create();
    ccNodeLoaderLibrary->registerDefaultCCNodeLoaders();

    // 创建 CCBReader，传入 this 作为 MemberVariableAssigner 和 SelectorResolver
    auto* ccbReader = new ccb::CCBReader(ccNodeLoaderLibrary, this, this);
    ccbReader->setCCBFilePath(s_ccbFilePath.c_str());

    // 读取文件
    ax::Node* node = ccbReader->readNodeGraphFromFile(filename.c_str(), this);

    mActionManager = ccbReader->getAnimationManager();
    AX_SAFE_RETAIN(mActionManager);

    ccbReader->release();

    if (node)
    {
        addChild(node);
        setContentSize(node->getContentSize());
    }
    else
    {
        AXLOGW("CCBContainer::loadCcbiFile('{}') - failed to load", filename);
    }
}

bool CCBContainer::hasAnimation(const std::string& actionname)
{
    if (!mActionManager)
        return false;

    int seqId = mActionManager->getSequenceId(actionname.c_str());
    return seqId >= 0;
}

void CCBContainer::runAnimation(const std::string& actionname)
{
    if (mActionManager)
    {
        mActionManager->runAnimations(actionname.c_str());
    }
}

void CCBContainer::playAutoPlaySequence()
{
    if (mActionManager && mActionManager->getAutoPlaySequenceId() != -1)
    {
        mActionManager->runAnimationsForSequenceIdTweenDuration(
            mActionManager->getAutoPlaySequenceId(), 0);
    }
}

ax::Object* CCBContainer::getVariable(const std::string& variablename)
{
    std::string var = variablename;
    std::transform(var.begin(), var.end(), var.begin(), ::tolower);
    auto it = mVariables.find(var);
    if (it != mVariables.end())
        return it->second;
    return nullptr;
}

ax::Node* CCBContainer::getCCNodeFromCCB(const std::string& variablename)
{
    auto* obj = getVariable(variablename);
    return obj ? dynamic_cast<ax::Node*>(obj) : nullptr;
}

ax::Sprite* CCBContainer::getCCSpriteFromCCB(const std::string& variablename)
{
    auto* obj = getVariable(variablename);
    return obj ? dynamic_cast<ax::Sprite*>(obj) : nullptr;
}

bool CCBContainer::getLoaded()
{
    return getChildrenCount() > 0;
}

void CCBContainer::unload()
{
    for (auto& pair : mVariables)
    {
        if (pair.second)
            pair.second->release();
    }
    mVariables.clear();
    mMenus.clear();
    AX_SAFE_RELEASE_NULL(mActionManager);
    mCCBContainerListener = nullptr;
    removeAllChildren();
}

void CCBContainer::onAnimationDone(const std::string& animationName)
{
    mCurAnimDoneName = animationName;
}

void CCBContainer::registerFunctionHandler(int nHandler)
{
    unregisterFunctionHandler();
    mScriptFunHandler = nHandler;
}

void CCBContainer::unregisterFunctionHandler()
{
    mScriptFunHandler = 0;
}

// ===== CCBMemberVariableAssigner 接口实现 =====

bool CCBContainer::onAssignCCBMemberVariable(ax::Object* pTarget, const char* pMemberVariableName, ax::Node* pNode)
{
    if (pTarget != this) return false;

    std::string var(pMemberVariableName);
    std::transform(var.begin(), var.end(), var.begin(), ::tolower);

    auto it = mVariables.find(var);
    if (it != mVariables.end())
    {
        if (it->second != pNode)
        {
            it->second->release();
            it->second = pNode;
            pNode->retain();
        }
        return true;
    }

    pNode->retain();
    mVariables.insert(std::make_pair(var, pNode));
    return true;
}

// ===== CCBSelectorResolver 接口实现 =====

std::function<void(ax::Object*)> CCBContainer::onResolveCCBCCMenuItemSelector(ax::Object* pTarget, const char* pSelectorName)
{
    if (pTarget != this) return nullptr;

    std::string name(pSelectorName);
    // 记录 selector name（待绑定到具体 MenuItem 时使用）
    // 实际回调会在菜单点击时触发

    return [this, name](ax::Object* sender) {
        AXLOGD("CCBContainer: menu item '{}' clicked", name);
        onMenuItemAction(name, sender);
        if (mCCBContainerListener)
            mCCBContainerListener->onMenuItemAction(name, sender, mCCBTag);
    };
}
