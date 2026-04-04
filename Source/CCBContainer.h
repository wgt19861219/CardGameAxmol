#pragma once

#include "axmol/axmol.h"
#include "CCBReader/CCNodeLoader.h"
#include "CCBReader/CCBAnimationManager.h"
#include <string>
#include <map>
#include <algorithm>

class CCBContainer : public ax::Node
    , public ccb::CCBMemberVariableAssigner
    , public ccb::CCBSelectorResolver
{
public:
    class CCBContainerListener
    {
    public:
        virtual void onMenuItemAction(const std::string& itemName, ax::Object* sender, int tag) {}
        virtual void onAnimationDone(const std::string& animationName) {}
    };

    CREATE_FUNC(CCBContainer);

    CCBContainer();
    CCBContainer(CCBContainerListener* listener, int tag = 0);
    virtual ~CCBContainer();

    virtual void onAnimationDone(const std::string& animationName);
    virtual void onMenuItemAction(const std::string& itemName, ax::Object* sender) {}
    virtual void unload();
    virtual bool getLoaded();

    void loadCcbiFile(const std::string& filename, bool forceLoad = false);
    bool hasAnimation(const std::string& actionname);
    void runAnimation(const std::string& actionname);
    void playAutoPlaySequence();
    ax::Object* getVariable(const std::string& variablename);
    void setListener(CCBContainerListener* listener, int tag = 0);
    void setAllChildColor(unsigned char r, unsigned char g, unsigned char b);

    ax::Node* getCCNodeFromCCB(const std::string& variablename);
    ax::Sprite* getCCSpriteFromCCB(const std::string& variablename);

    static void setCCBFilePath(const std::string& ccbFilePath)
    {
        s_ccbFilePath = ccbFilePath;
    }

    virtual bool init();

    void registerFunctionHandler(int nHandler);
    void unregisterFunctionHandler();
    std::string getCurAnimationDoneName() { return mCurAnimDoneName; }

    int mIndex;

    // CCBMemberVariableAssigner 接口
    bool onAssignCCBMemberVariable(ax::Object* pTarget, const char* pMemberVariableName, ax::Node* pNode) override;

    // CCBSelectorResolver 接口
    std::function<void(ax::Object*)> onResolveCCBCCMenuItemSelector(ax::Object* pTarget, const char* pSelectorName) override;

private:
    static std::string s_ccbFilePath;

    typedef std::map<std::string, ax::Object*> VariableMap;
    VariableMap mVariables;

    typedef std::map<ax::Object*, std::string> MenuItemMap;
    MenuItemMap mMenus;

    ccb::CCBAnimationManager* mActionManager;
    CCBContainerListener* mCCBContainerListener;
    int mCCBTag;
    std::string mLoadedCCBFile;
    int mScriptFunHandler;
    std::string mCurAnimDoneName;
};
