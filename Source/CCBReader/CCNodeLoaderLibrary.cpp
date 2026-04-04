#include "CCNodeLoaderLibrary.h"
#include "CCNodeLoader.h"

namespace ccb {

CCNodeLoaderLibrary* CCNodeLoaderLibrary::create()
{
    auto* ret = new CCNodeLoaderLibrary();
    ret->autorelease();
    return ret;
}

CCNodeLoaderLibrary::~CCNodeLoaderLibrary()
{
    for (auto& pair : mLoaders)
        AX_SAFE_RELEASE(pair.second);
    mLoaders.clear();
}

void CCNodeLoaderLibrary::registerDefaultCCNodeLoaders()
{
    // 注册基础节点加载器
    registerCCNodeLoader("CCNode",                CCNodeLoader::loader());
    registerCCNodeLoader("CCLayer",               CCLayerLoader::loader());
    registerCCNodeLoader("CCLayerColor",          CCLayerColorLoader::loader());
    registerCCNodeLoader("CCLayerGradient",       CCLayerGradientLoader::loader());
    registerCCNodeLoader("CCSprite",              CCSpriteLoader::loader());
    registerCCNodeLoader("CCLabelBMFont",         CCLabelBMFontLoader::loader());
    registerCCNodeLoader("CCLabelTTF",            CCLabelTTFLoader::loader());
    registerCCNodeLoader("CCScale9Sprite",        CCScale9SpriteLoader::loader());
    registerCCNodeLoader("CCScrollView",          CCScrollViewLoader::loader());
    registerCCNodeLoader("CCBFile",               CCBFileLoader::loader());
    registerCCNodeLoader("CCMenu",                CCMenuLoader::loader());
    registerCCNodeLoader("CCMenuItemImage",       CCMenuItemImageLoader::loader());
    registerCCNodeLoader("CCMenuCCBFile",         CCMenuItemCCBFileLoader::loader());
    registerCCNodeLoader("CCControlButton",       CCControlButtonLoader::loader());
    registerCCNodeLoader("CCParticleSystemQuad",  CCParticleSystemQuadLoader::loader());
    registerCCNodeLoader("CCBClippingNode",       CCBClippingNodeLoader::loader());
    registerCCNodeLoader("CCClippingNode",        CCClippingNodeLoader::loader());
    registerCCNodeLoader("CCBFileNew",            CCBFileNewLoader::loader());
}

void CCNodeLoaderLibrary::registerCCNodeLoader(const std::string& className, CCNodeLoader* loader)
{
    auto it = mLoaders.find(className);
    if (it != mLoaders.end())
    {
        AX_SAFE_RELEASE(it->second);
        it->second = loader;
    }
    else
    {
        mLoaders[className] = loader;
    }
    AX_SAFE_RETAIN(loader);
}

void CCNodeLoaderLibrary::unregisterCCNodeLoader(const std::string& className)
{
    auto it = mLoaders.find(className);
    if (it != mLoaders.end())
    {
        AX_SAFE_RELEASE(it->second);
        mLoaders.erase(it);
    }
}

CCNodeLoader* CCNodeLoaderLibrary::getCCNodeLoader(const std::string& className)
{
    auto it = mLoaders.find(className);
    if (it != mLoaders.end())
        return it->second;
    return nullptr;
}

} // namespace ccb
