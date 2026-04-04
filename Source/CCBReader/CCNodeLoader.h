#pragma once

#include "axmol/axmol.h"
#include "CCBValue.h"
#include <string>
#include <vector>
#include <functional>

namespace ccb {

class CCBReader;
class CCNodeLoader;

// 前向声明回调接口
class CCBSelectorResolver
{
public:
    virtual ~CCBSelectorResolver() = default;
    virtual std::function<void(ax::Object*)> onResolveCCBCCMenuItemSelector(ax::Object* pTarget, const char* pSelectorName) = 0;
};

class CCBMemberVariableAssigner
{
public:
    virtual ~CCBMemberVariableAssigner() = default;
    virtual bool onAssignCCBMemberVariable(ax::Object* pTarget, const char* pMemberVariableName, ax::Node* pNode) = 0;
};

class CCNodeLoaderListener
{
public:
    virtual ~CCNodeLoaderListener() = default;
    virtual void onNodeLoaded(ax::Node* pNode, CCNodeLoader* pNodeLoader) = 0;
};

// 属性类型枚举
enum
{
    kCCBPropTypePosition = 0,
    kCCBPropTypeSize,
    kCCBPropTypePoint,
    kCCBPropTypePointLock,
    kCCBPropTypeScaleLock,
    kCCBPropTypeDegrees,
    kCCBPropTypeInteger,
    kCCBPropTypeFloat,
    kCCBPropTypeFloatVar,
    kCCBPropTypeCheck,
    kCCBPropTypeSpriteFrame,
    kCCBPropTypeTexture,
    kCCBPropTypeByte,
    kCCBPropTypeColor3,
    kCCBPropTypeColor4FVar,
    kCCBPropTypeFlip,
    kCCBPropTypeBlendmode,
    kCCBPropTypeFntFile,
    kCCBPropTypeText,
    kCCBPropTypeFontTTF,
    kCCBPropTypeIntegerLabeled,
    kCCBPropTypeBlock,
    kCCBPropTypeAnimation,
    kCCBPropTypeCCBFile,
    kCCBPropTypeString,
    kCCBPropTypeBlockCCControl,
    kCCBPropTypeFloatScale,
    kCCBPropTypeFloatXY,
    kCCBPropTypeCCBFileNew
};

// 节点加载器基类
class CCNodeLoader : public ax::Object
{
public:
    virtual ~CCNodeLoader();

    ax::Node* loadCCNode(ax::Node* pParent, CCBReader* pCCBReader);

    // 静态 loader() 方法由子类实现
    static CCNodeLoader* loader();

protected:
    CCNodeLoader();

    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader);
    virtual void onHandlePropTypePosition(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Vec2 pPosition, CCBReader* pCCBReader);
    virtual void onHandlePropTypePoint(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Vec2 pPoint, CCBReader* pCCBReader);
    virtual void onHandlePropTypePointLock(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Vec2 pPointLock, CCBReader* pCCBReader);
    virtual void onHandlePropTypeSize(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Size pSize, CCBReader* pCCBReader);
    virtual void onHandlePropTypeScaleLock(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pScaleLock, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloat, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFloatXY(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Vec2 pFloatXY, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFloatScale(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloatScale, CCBReader* pCCBReader);
    virtual void onHandlePropTypeDegrees(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pDegrees, CCBReader* pCCBReader);
    virtual void onHandlePropTypeInteger(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, int pInteger, CCBReader* pCCBReader);
    virtual void onHandlePropTypeIntegerLabeled(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, int pIntegerLabeled, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFloatVar(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloatVar, CCBReader* pCCBReader);
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader);
    virtual void onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::SpriteFrame* pSpriteFrame, CCBReader* pCCBReader);
    virtual void onHandlePropTypeTexture(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Texture2D* pTexture2D, CCBReader* pCCBReader);
    virtual void onHandlePropTypeByte(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, unsigned char pByte, CCBReader* pCCBReader);
    virtual void onHandlePropTypeColor3(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Color32 pColor3B, CCBReader* pCCBReader);
    virtual void onHandlePropTypeColor4FVar(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Color pColor4FVar, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFlip(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pFlip, CCBReader* pCCBReader);
    virtual void onHandlePropTypeBlendmode(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, unsigned int pBlendmode, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFntFile(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pFntFile, CCBReader* pCCBReader);
    virtual void onHandlePropTypeText(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pText, CCBReader* pCCBReader);
    virtual void onHandlePropTypeFontTTF(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pFontTTF, CCBReader* pCCBReader);
    virtual void onHandlePropTypeString(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pString, CCBReader* pCCBReader);
    virtual void onHandlePropTypeBlock(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader);
    virtual void onHandlePropTypeBlockCCControl(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader);
    virtual void onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Node* pCCBFileNode, CCBReader* pCCBReader);
    virtual void onHandlePropTypeAnimation(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pAnimation, CCBReader* pCCBReader);

private:
    void parseProperties(ax::Node* pNode, ax::Node* pParent, CCBReader* pCCBReader);
    void parsePropTypePosition(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, int type, CCBReader* pCCBReader);
    void parsePropTypePoint(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader);
    void parsePropTypeSize(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, int type, CCBReader* pCCBReader);
    void parsePropTypeScaleLock(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader, float* pScale);
};

// ===== 具体节点加载器 =====

class CCLayerLoader : public CCNodeLoader
{
public:
    static CCLayerLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCLayerColorLoader : public CCNodeLoader
{
public:
    static CCLayerColorLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCLayerGradientLoader : public CCNodeLoader
{
public:
    static CCLayerGradientLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCSpriteLoader : public CCNodeLoader
{
public:
    static CCSpriteLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCLabelTTFLoader : public CCNodeLoader
{
public:
    static CCLabelTTFLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCLabelBMFontLoader : public CCNodeLoader
{
public:
    static CCLabelBMFontLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCScale9SpriteLoader : public CCNodeLoader
{
public:
    static CCScale9SpriteLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCMenuLoader : public CCNodeLoader
{
public:
    static CCMenuLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCMenuItemImageLoader : public CCNodeLoader
{
public:
    static CCMenuItemImageLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::SpriteFrame* pSpriteFrame, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeBlock(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader) override;
};

class CCMenuItemCCBFileLoader : public CCNodeLoader
{
public:
    static CCMenuItemCCBFileLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeBlock(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader) override;
};

class CCControlButtonLoader : public CCNodeLoader
{
public:
    static CCControlButtonLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeBlockCCControl(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::SpriteFrame* pSpriteFrame, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeSize(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Size pSize, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloat, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeColor3(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Color32 pColor3B, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeString(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pString, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeFontTTF(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, const char* pFontTTF, CCBReader* pCCBReader) override;
};

class CCBFileLoader : public CCNodeLoader
{
public:
    static CCBFileLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCBFileNewLoader : public CCNodeLoader
{
public:
    static CCBFileNewLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
};

class CCScrollViewLoader : public CCNodeLoader
{
public:
    static CCScrollViewLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeSize(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Size pSize, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloat, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Node* pCCBFileNode, CCBReader* pCCBReader) override;
};

class CCParticleSystemQuadLoader : public CCNodeLoader
{
public:
    static CCParticleSystemQuadLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloat, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeInteger(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, int pInteger, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypePoint(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Vec2 pPoint, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeColor3(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Color32 pColor3B, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeBlendmode(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, unsigned int pBlendmode, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeTexture(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Texture2D* pTexture2D, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::SpriteFrame* pSpriteFrame, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeByte(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, unsigned char pByte, CCBReader* pCCBReader) override;
};

class CCBClippingNodeLoader : public CCNodeLoader
{
public:
    static CCBClippingNodeLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloat, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Node* pCCBFileNode, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeInteger(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, int pInteger, CCBReader* pCCBReader) override;
};

class CCClippingNodeLoader : public CCNodeLoader
{
public:
    static CCClippingNodeLoader* loader();
protected:
    virtual ax::Node* createCCNode(ax::Node* pParent, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, float pFloat, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, bool pCheck, CCBReader* pCCBReader) override;
    virtual void onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent, const char* pPropertyName, ax::Node* pCCBFileNode, CCBReader* pCCBReader) override;
};

} // namespace ccb
