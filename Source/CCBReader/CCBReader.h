#pragma once

#include "axmol/axmol.h"
#include "CCNodeLoader.h"
#include "CCNodeLoaderLibrary.h"
#include "CCData.h"
#include <string>
#include <vector>
#include <set>
#include <unordered_map>

namespace ccb {

// 前向声明
class CCData;
class CCBAnimationManager;
class CCBSequence;
class CCBKeyframe;
class CCBSequenceProperty;

// 版本号
#define kCCBVersion 5

// 浮点编码类型
enum {
    kCCBFloat0 = 0,
    kCCBFloat1,
    kCCBFloatMinus1,
    kCCBFloat05,
    kCCBFloatInteger,
    kCCBFloatFull
};

// 目标类型
enum {
    kCCBTargetTypeNone = 0,
    kCCBTargetTypeDocumentRoot = 1,
    kCCBTargetTypeOwner = 2,
};

// CCBFile 节点（嵌套 CCB 文件的容器）
class CCBFile : public ax::Node
{
public:
    CCBFile();
    static CCBFile* create();

    ax::Node* getCCBFileNode() { return mCCBFileNode; }
    void setCCBFileNode(ax::Node* pNode);

private:
    ax::Node* mCCBFileNode = nullptr;
};

// CCBI 文件读取器
class CCBReader : public ax::Object
{
public:
    CCBReader(CCNodeLoaderLibrary* pCCNodeLoaderLibrary,
              CCBMemberVariableAssigner* pCCBMemberVariableAssigner = nullptr,
              CCBSelectorResolver* pCCBSelectorResolver = nullptr);
    CCBReader(CCBReader* pCCBReader);
    virtual ~CCBReader();

    void setCCBRootPath(const char* pCCBRootPath);
    const std::string& getCCBRootPath() const { return mCCBRootPath; }

    void setCCBFilePath(const char* pCCBFilePath);
    const std::string& getCCBFilePath() const { return mCCBFilePath; }

    ax::Node* readNodeGraphFromFile(const char* pCCBFileName);
    ax::Node* readNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner);
    ax::Node* readNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner, const ax::Size& parentSize);
    ax::Scene* createSceneWithNodeGraphFromFile(const char* pCCBFileName);
    ax::Scene* createSceneWithNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner);
    ax::Scene* createSceneWithNodeGraphFromFile(const char* pCCBFileName, ax::Object* pOwner, const ax::Size& parentSize);

    ax::Node* readNodeGraphFromData(CCData* pData, ax::Object* pOwner, const ax::Size& parentSize);

    CCBAnimationManager* getAnimationManager();
    void setAnimationManager(CCBAnimationManager* pAnimationManager);

    CCBMemberVariableAssigner* getCCBMemberVariableAssigner() { return mCCBMemberVariableAssigner; }
    CCBSelectorResolver* getCCBSelectorResolver() { return mCCBSelectorResolver; }

    std::set<std::string>* getAnimatedProperties() { return mAnimatedProps; }
    std::set<std::string>& getLoadedSpriteSheet() { return mLoadedSpriteSheets; }
    ax::Object* getOwner() { return mOwner; }

    // 二进制数据读取方法
    int readInt(bool pSigned);
    unsigned char readByte();
    bool readBool();
    std::string readUTF8();
    float readFloat();
    std::string readCachedString();

    bool isJSControlled() { return jsControlled; }

    // 添加回调/Outlet
    void addOwnerOutletName(const std::string& name);
    void addOwnerOutletNode(ax::Node* node);
    void addOwnerCallbackName(const std::string& name);
    void addOwnerCallbackNode(ax::Node* node);
    void addDocumentCallbackName(const std::string& name);
    void addDocumentCallbackNode(ax::Node* node);

    // 静态工具方法
    static std::string lastPathComponent(const char* pString);
    static std::string deletePathExtension(const char* pString);
    static std::string toLowerCase(const char* pCCString);
    static bool endsWith(const char* pString, const char* pEnding);
    static float getResolutionScale();
    static void setResolutionScale(float scale);

    // 数据成员（CCNodeLoader 需要直接访问）
    CCData* mData = nullptr;
    unsigned char* mBytes = nullptr;
    int mCurrentByte = 0;
    int mCurrentBit = 0;
    std::vector<std::string> mStringCache;
    bool jsControlled = false;

    ax::Vector<ax::Object*> mOwnerOutletNodes;
    ax::Vector<ax::Object*> mOwnerCallbackNodes;

private:
    bool init();
    ax::Node* readNodeGraph(ax::Node* pParent);
    ax::Node* readFileWithCleanUp(bool bCleanUp);
    bool readHeader();
    bool readStringCache();
    bool readSequences();
    CCBKeyframe* readKeyframe(int type);
    bool readCallbackKeyframesForSeq(CCBSequence* seq);
    bool readSoundKeyframesForSeq(CCBSequence* seq);

    bool getBit();
    void alignBits();
    void cleanUpNodeGraph(ax::Node* pNode);

    std::set<std::string> mLoadedSpriteSheets;
    ax::Object* mOwner = nullptr;
    CCBAnimationManager* mActionManager = nullptr;
    std::set<std::string>* mAnimatedProps = nullptr;

    CCNodeLoaderLibrary* mCCNodeLoaderLibrary = nullptr;
    CCBMemberVariableAssigner* mCCBMemberVariableAssigner = nullptr;
    CCBSelectorResolver* mCCBSelectorResolver = nullptr;

    std::vector<std::string> mOwnerOutletNames;
    std::vector<std::string> mOwnerCallbackNames;
    std::string mCCBRootPath;
    std::string mCCBFilePath;
    std::string mCCBName;

    friend class CCNodeLoader;
};

} // namespace ccb
