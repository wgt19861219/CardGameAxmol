#include "CCNodeLoader.h"
#include "CCBValue.h"
#include "CCData.h"

#include "axmol/2d/Sprite.h"
#include "axmol/2d/Label.h"
#include "axmol/2d/Menu.h"
#include "axmol/2d/MenuItem.h"
#include "axmol/2d/ParticleSystemQuad.h"
#include "axmol/2d/ClippingNode.h"
#include "axmol/2d/Layer.h"
#include "axmol/ui/UIScale9Sprite.h"
#include "axmol/ui/UIScrollView.h"
#include "axmol/ui/UIButton.h"

#include <cstring>

namespace ccb {

// 属性名称常量
static const char* PROPERTY_POSITION = "position";
static const char* PROPERTY_CONTENTSIZE = "contentSize";
static const char* PROPERTY_SKEW = "skew";
static const char* PROPERTY_ANCHORPOINT = "anchorPoint";
static const char* PROPERTY_SCALE = "scale";
static const char* PROPERTY_ROTATION = "rotation";
static const char* PROPERTY_ROTATIONX = "rotationX";
static const char* PROPERTY_ROTATIONY = "rotationY";
static const char* PROPERTY_TAG = "tag";
static const char* PROPERTY_IGNOREANCHORPOINTFORPOSITION = "ignoreAnchorPointForPosition";
static const char* PROPERTY_VISIBLE = "visible";
static const char* PROPERTY_DISPLAYFRAME = "displayFrame";
static const char* PROPERTY_SAFERECT = "safeRect";
static const char* PROPERTY_ENABLED = "enabled";
static const char* PROPERTY_NORMAL_IMAGE = "normalSpriteFrame";
static const char* PROPERTY_SELECTED_IMAGE = "selectedSpriteFrame";
static const char* PROPERTY_DISABLED_IMAGE = "disabledSpriteFrame";
static const char* PROPERTY_TITLE_TEXT = "titleText";
static const char* PROPERTY_TITLE_FONT = "titleFontName";
static const char* PROPERTY_TITLE_COLOR = "titleColor";
static const char* PROPERTY_ZOOM_ON_TOUCH = "zoomOnTouch";
static const char* PROPERTY_INSET_LEFT = "insetLeft";
static const char* PROPERTY_INSET_TOP = "insetTop";
static const char* PROPERTY_INSET_RIGHT = "insetRight";
static const char* PROPERTY_INSET_BOTTOM = "insetBottom";

#define ASSERT_FAIL_UNEXPECTED_PROPERTY(PROPERTY) \
    AXLOGW("Unexpected property: '{}'!", PROPERTY);

#define ASSERT_FAIL_UNEXPECTED_PROPERTYTYPE(PROPERTYTYPE) \
    AXLOGW("Unexpected property type: '{}'!", PROPERTYTYPE);

// =====================================================================
// CCNodeLoader 基类实现
// =====================================================================

CCNodeLoader::CCNodeLoader()
{
}

CCNodeLoader::~CCNodeLoader()
{
}

CCNodeLoader* CCNodeLoader::loader()
{
    auto* ret = new CCNodeLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCNodeLoader::loadCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    ax::Node* node = this->createCCNode(pParent, pCCBReader);
    return node;
}

ax::Node* CCNodeLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::Node::create();
}

// =====================================================================
// parseProperties - 核心属性解析分发
// =====================================================================

void CCNodeLoader::parseProperties(ax::Node* pNode, ax::Node* pParent, CCBReader* pCCBReader)
{
    // 由 CCBReader 负责调用，此处为简化实现
    // 实际读取逻辑在 CCBReader::readNodeGraph 中完成
}

// =====================================================================
// parsePropType 方法 - 从 CCBReader 读取值
// =====================================================================

void CCNodeLoader::parsePropTypePosition(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, int type,
                                          CCBReader* pCCBReader)
{
    // 位置解析在 CCBReader 中完成
}

void CCNodeLoader::parsePropTypePoint(ax::Node* pNode, ax::Node* pParent,
                                       const char* pPropertyName, CCBReader* pCCBReader)
{
    // 点解析在 CCBReader 中完成
}

void CCNodeLoader::parsePropTypeSize(ax::Node* pNode, ax::Node* pParent,
                                      const char* pPropertyName, int type,
                                      CCBReader* pCCBReader)
{
    // 尺寸解析在 CCBReader 中完成
}

void CCNodeLoader::parsePropTypeScaleLock(ax::Node* pNode, ax::Node* pParent,
                                           const char* pPropertyName,
                                           CCBReader* pCCBReader, float* pScale)
{
    // 缩放解析在 CCBReader 中完成
}

// =====================================================================
// onHandlePropType 方法 - 基类默认处理
// =====================================================================

void CCNodeLoader::onHandlePropTypePosition(ax::Node* pNode, ax::Node* pParent,
                                             const char* pPropertyName, ax::Vec2 pPosition,
                                             CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_POSITION) == 0) {
        pNode->setPosition(pPosition);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypePoint(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, ax::Vec2 pPoint,
                                          CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_ANCHORPOINT) == 0) {
        pNode->setAnchorPoint(pPoint);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypePointLock(ax::Node* pNode, ax::Node* pParent,
                                              const char* pPropertyName, ax::Vec2 pPointLock,
                                              CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeSize(ax::Node* pNode, ax::Node* pParent,
                                         const char* pPropertyName, ax::Size pSize,
                                         CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_CONTENTSIZE) == 0) {
        pNode->setContentSize(pSize);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypeScaleLock(ax::Node* pNode, ax::Node* pParent,
                                              const char* pPropertyName, float pScaleLock,
                                              CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_SCALE) == 0) {
        pNode->setScale(pScaleLock);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, float pFloat,
                                          CCBReader* pCCBReader)
{
    // 可能是自定义属性
    AXLOGW("Unhandled float property: '{}' = {}", pPropertyName, pFloat);
}

void CCNodeLoader::onHandlePropTypeFloatXY(ax::Node* pNode, ax::Node* pParent,
                                            const char* pPropertyName, ax::Vec2 pFloatXY,
                                            CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_SKEW) == 0) {
        pNode->setSkewX(pFloatXY.x);
        pNode->setSkewY(pFloatXY.y);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypeFloatScale(ax::Node* pNode, ax::Node* pParent,
                                               const char* pPropertyName, float pFloatScale,
                                               CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeDegrees(ax::Node* pNode, ax::Node* pParent,
                                            const char* pPropertyName, float pDegrees,
                                            CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_ROTATION) == 0) {
        pNode->setRotation(pDegrees);
    } else if (strcmp(pPropertyName, PROPERTY_ROTATIONX) == 0) {
        pNode->setRotationSkewX(pDegrees);
    } else if (strcmp(pPropertyName, PROPERTY_ROTATIONY) == 0) {
        pNode->setRotationSkewY(pDegrees);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypeInteger(ax::Node* pNode, ax::Node* pParent,
                                            const char* pPropertyName, int pInteger,
                                            CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_TAG) == 0) {
        pNode->setTag(pInteger);
    } else {
        AXLOGW("Unhandled integer property: '{}' = {}", pPropertyName, pInteger);
    }
}

void CCNodeLoader::onHandlePropTypeIntegerLabeled(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName, int pIntegerLabeled,
                                                    CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeFloatVar(ax::Node* pNode, ax::Node* pParent,
                                              const char* pPropertyName, float pFloatVar,
                                              CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, bool pCheck,
                                          CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_VISIBLE) == 0) {
        pNode->setVisible(pCheck);
    } else if (strcmp(pPropertyName, PROPERTY_IGNOREANCHORPOINTFORPOSITION) == 0) {
        pNode->setIgnoreAnchorPointForPosition(pCheck);
    } else {
        AXLOGW("Unhandled check property: '{}' = {}", pPropertyName, pCheck);
    }
}

void CCNodeLoader::onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent,
                                                 const char* pPropertyName,
                                                 ax::SpriteFrame* pSpriteFrame,
                                                 CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_DISPLAYFRAME) == 0) {
        auto* sprite = dynamic_cast<ax::Sprite*>(pNode);
        if (sprite && pSpriteFrame) {
            sprite->setSpriteFrame(pSpriteFrame);
        }
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCNodeLoader::onHandlePropTypeTexture(ax::Node* pNode, ax::Node* pParent,
                                             const char* pPropertyName,
                                             ax::Texture2D* pTexture2D,
                                             CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeByte(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, unsigned char pByte,
                                          CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeColor3(ax::Node* pNode, ax::Node* pParent,
                                            const char* pPropertyName, ax::Color32 pColor3B,
                                            CCBReader* pCCBReader)
{
    // 大部分节点通过 setColor 接受颜色
    pNode->setColor(pColor3B);
}

void CCNodeLoader::onHandlePropTypeColor4FVar(ax::Node* pNode, ax::Node* pParent,
                                                const char* pPropertyName,
                                                ax::Color pColor4FVar,
                                                CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeFlip(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, bool pFlip,
                                          CCBReader* pCCBReader)
{
    auto* sprite = dynamic_cast<ax::Sprite*>(pNode);
    if (sprite) {
        if (strcmp(pPropertyName, "flipX") == 0 || strcmp(pPropertyName, "flip") == 0) {
            sprite->setFlippedX(pFlip);
        } else if (strcmp(pPropertyName, "flipY") == 0) {
            sprite->setFlippedY(pFlip);
        }
    }
}

void CCNodeLoader::onHandlePropTypeBlendmode(ax::Node* pNode, ax::Node* pParent,
                                               const char* pPropertyName,
                                               unsigned int pBlendmode,
                                               CCBReader* pCCBReader)
{
    // pBlendmode 直接存储了混合模式的 src|dst 组合值
    auto* sprite = dynamic_cast<ax::Sprite*>(pNode);
    if (sprite) {
        ax::BlendFunc blendFunc;
        blendFunc.src = static_cast<ax::rhi::BlendFactor>(pBlendmode >> 16);
        blendFunc.dst = static_cast<ax::rhi::BlendFactor>(pBlendmode & 0xFFFF);
        sprite->setBlendFunc(blendFunc);
    }
}

void CCNodeLoader::onHandlePropTypeFntFile(ax::Node* pNode, ax::Node* pParent,
                                             const char* pPropertyName, const char* pFntFile,
                                             CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeText(ax::Node* pNode, ax::Node* pParent,
                                          const char* pPropertyName, const char* pText,
                                          CCBReader* pCCBReader)
{
    auto* label = dynamic_cast<ax::Label*>(pNode);
    if (label) {
        label->setString(pText ? pText : "");
    }
}

void CCNodeLoader::onHandlePropTypeFontTTF(ax::Node* pNode, ax::Node* pParent,
                                              const char* pPropertyName, const char* pFontTTF,
                                              CCBReader* pCCBReader)
{
    auto* label = dynamic_cast<ax::Label*>(pNode);
    if (label) {
        // 系统字体名设置
        label->setSystemFontName(pFontTTF);
    }
}

void CCNodeLoader::onHandlePropTypeString(ax::Node* pNode, ax::Node* pParent,
                                            const char* pPropertyName, const char* pString,
                                            CCBReader* pCCBReader)
{
    AXLOGW("Unhandled string property: '{}' = '{}'", pPropertyName, pString ? pString : "");
}

void CCNodeLoader::onHandlePropTypeBlock(ax::Node* pNode, ax::Node* pParent,
                                           const char* pPropertyName,
                                           CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeBlockCCControl(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName,
                                                    CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent,
                                              const char* pPropertyName,
                                              ax::Node* pCCBFileNode,
                                              CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

void CCNodeLoader::onHandlePropTypeAnimation(ax::Node* pNode, ax::Node* pParent,
                                               const char* pPropertyName,
                                               const char* pAnimation,
                                               CCBReader* pCCBReader)
{
    ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
}

// =====================================================================
// CCLayerLoader
// =====================================================================

CCLayerLoader* CCLayerLoader::loader()
{
    auto* ret = new CCLayerLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCLayerLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::Layer::create();
}

// =====================================================================
// CCLayerColorLoader
// =====================================================================

CCLayerColorLoader* CCLayerColorLoader::loader()
{
    auto* ret = new CCLayerColorLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCLayerColorLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::LayerColor::create();
}

// =====================================================================
// CCLayerGradientLoader
// =====================================================================

CCLayerGradientLoader* CCLayerGradientLoader::loader()
{
    auto* ret = new CCLayerGradientLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCLayerGradientLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::LayerGradient::create();
}

// =====================================================================
// CCSpriteLoader
// =====================================================================

CCSpriteLoader* CCSpriteLoader::loader()
{
    auto* ret = new CCSpriteLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCSpriteLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::Sprite::create();
}

// =====================================================================
// CCLabelTTFLoader
// =====================================================================

CCLabelTTFLoader* CCLabelTTFLoader::loader()
{
    auto* ret = new CCLabelTTFLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCLabelTTFLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::Label::createWithSystemFont("", "Arial", 12.0f);
}

// =====================================================================
// CCLabelBMFontLoader
// =====================================================================

CCLabelBMFontLoader* CCLabelBMFontLoader::loader()
{
    auto* ret = new CCLabelBMFontLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCLabelBMFontLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    // BMFont 需要字体文件路径，先用空占位
    // 实际字体会在 parseProperties 中通过 onHandlePropTypeFntFile 设置
    return ax::Label::create();
}

// =====================================================================
// CCScale9SpriteLoader
// =====================================================================

CCScale9SpriteLoader* CCScale9SpriteLoader::loader()
{
    auto* ret = new CCScale9SpriteLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCScale9SpriteLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::ui::Scale9Sprite::create();
}

// =====================================================================
// CCMenuLoader
// =====================================================================

CCMenuLoader* CCMenuLoader::loader()
{
    auto* ret = new CCMenuLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCMenuLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::Menu::create();
}

// =====================================================================
// CCMenuItemImageLoader
// =====================================================================

CCMenuItemImageLoader* CCMenuItemImageLoader::loader()
{
    auto* ret = new CCMenuItemImageLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCMenuItemImageLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::MenuItemImage::create();
}

void CCMenuItemImageLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName, bool pCheck,
                                                    CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_VISIBLE) == 0) {
        pNode->setVisible(pCheck);
    } else if (strcmp(pPropertyName, PROPERTY_ENABLED) == 0) {
        auto* item = dynamic_cast<ax::MenuItem*>(pNode);
        if (item) {
            item->setEnabled(pCheck);
        }
    } else {
        CCNodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, pCCBReader);
    }
}

void CCMenuItemImageLoader::onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent,
                                                          const char* pPropertyName,
                                                          ax::SpriteFrame* pSpriteFrame,
                                                          CCBReader* pCCBReader)
{
    auto* item = dynamic_cast<ax::MenuItemImage*>(pNode);
    if (item && pSpriteFrame) {
        if (strcmp(pPropertyName, PROPERTY_NORMAL_IMAGE) == 0 ||
            strcmp(pPropertyName, PROPERTY_DISPLAYFRAME) == 0) {
            item->setNormalImage(ax::Sprite::createWithSpriteFrame(pSpriteFrame));
        } else if (strcmp(pPropertyName, PROPERTY_SELECTED_IMAGE) == 0) {
            item->setSelectedImage(ax::Sprite::createWithSpriteFrame(pSpriteFrame));
        } else if (strcmp(pPropertyName, PROPERTY_DISABLED_IMAGE) == 0) {
            item->setDisabledImage(ax::Sprite::createWithSpriteFrame(pSpriteFrame));
        }
    }
}

void CCMenuItemImageLoader::onHandlePropTypeBlock(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName,
                                                    CCBReader* pCCBReader)
{
    // 回调通过 CCBReader 的 CCBSelectorResolver 设置
    // 具体的回调绑定在 CCBReader 中处理
}

// =====================================================================
// CCMenuItemCCBFileLoader
// =====================================================================

CCMenuItemCCBFileLoader* CCMenuItemCCBFileLoader::loader()
{
    auto* ret = new CCMenuItemCCBFileLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCMenuItemCCBFileLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::MenuItemImage::create();
}

void CCMenuItemCCBFileLoader::onHandlePropTypeBlock(ax::Node* pNode, ax::Node* pParent,
                                                      const char* pPropertyName,
                                                      CCBReader* pCCBReader)
{
    // 回调绑定由 CCBReader 处理
}

void CCMenuItemCCBFileLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                                      const char* pPropertyName, bool pCheck,
                                                      CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_ENABLED) == 0) {
        auto* item = dynamic_cast<ax::MenuItem*>(pNode);
        if (item) {
            item->setEnabled(pCheck);
        }
    } else {
        CCNodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, pCCBReader);
    }
}

// =====================================================================
// CCControlButtonLoader
// =====================================================================

CCControlButtonLoader* CCControlButtonLoader::loader()
{
    auto* ret = new CCControlButtonLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCControlButtonLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::ui::Button::create();
}

void CCControlButtonLoader::onHandlePropTypeBlockCCControl(ax::Node* pNode, ax::Node* pParent,
                                                             const char* pPropertyName,
                                                             CCBReader* pCCBReader)
{
    // 控件回调绑定由 CCBReader 处理
}

void CCControlButtonLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName, bool pCheck,
                                                    CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_VISIBLE) == 0) {
        pNode->setVisible(pCheck);
    } else if (strcmp(pPropertyName, PROPERTY_ENABLED) == 0) {
        auto* btn = dynamic_cast<ax::ui::Button*>(pNode);
        if (btn) {
            btn->setEnabled(pCheck);
            btn->setBright(pCheck);
        }
    } else {
        CCNodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, pCCBReader);
    }
}

void CCControlButtonLoader::onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent,
                                                          const char* pPropertyName,
                                                          ax::SpriteFrame* pSpriteFrame,
                                                          CCBReader* pCCBReader)
{
    auto* btn = dynamic_cast<ax::ui::Button*>(pNode);
    if (btn && pSpriteFrame) {
        // Button 使用 TextureResType::PLIST 模式
        // 简化处理：将 SpriteFrame 的纹理名设置到 Button
    }
}

void CCControlButtonLoader::onHandlePropTypeSize(ax::Node* pNode, ax::Node* pParent,
                                                   const char* pPropertyName, ax::Size pSize,
                                                   CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_CONTENTSIZE) == 0) {
        pNode->setContentSize(pSize);
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCControlButtonLoader::onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName, float pFloat,
                                                    CCBReader* pCCBReader)
{
    auto* btn = dynamic_cast<ax::ui::Button*>(pNode);
    if (btn) {
        if (strcmp(pPropertyName, PROPERTY_INSET_LEFT) == 0) {
            // Scale9 inset left
        } else if (strcmp(pPropertyName, PROPERTY_INSET_TOP) == 0) {
            // Scale9 inset top
        } else if (strcmp(pPropertyName, PROPERTY_INSET_RIGHT) == 0) {
            // Scale9 inset right
        } else if (strcmp(pPropertyName, PROPERTY_INSET_BOTTOM) == 0) {
            // Scale9 inset bottom
        } else {
            CCNodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, pCCBReader);
        }
    } else {
        CCNodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, pCCBReader);
    }
}

void CCControlButtonLoader::onHandlePropTypeColor3(ax::Node* pNode, ax::Node* pParent,
                                                     const char* pPropertyName,
                                                     ax::Color32 pColor3B,
                                                     CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_TITLE_COLOR) == 0) {
        auto* btn = dynamic_cast<ax::ui::Button*>(pNode);
        if (btn) {
            btn->setTitleColor(pColor3B);
        }
    } else {
        CCNodeLoader::onHandlePropTypeColor3(pNode, pParent, pPropertyName, pColor3B, pCCBReader);
    }
}

void CCControlButtonLoader::onHandlePropTypeString(ax::Node* pNode, ax::Node* pParent,
                                                     const char* pPropertyName,
                                                     const char* pString,
                                                     CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_TITLE_TEXT) == 0) {
        auto* btn = dynamic_cast<ax::ui::Button*>(pNode);
        if (btn) {
            btn->setTitleText(pString ? pString : "");
        }
    } else {
        CCNodeLoader::onHandlePropTypeString(pNode, pParent, pPropertyName, pString, pCCBReader);
    }
}

void CCControlButtonLoader::onHandlePropTypeFontTTF(ax::Node* pNode, ax::Node* pParent,
                                                       const char* pPropertyName,
                                                       const char* pFontTTF,
                                                       CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_TITLE_FONT) == 0) {
        auto* btn = dynamic_cast<ax::ui::Button*>(pNode);
        if (btn) {
            btn->setTitleFontName(pFontTTF);
        }
    } else {
        CCNodeLoader::onHandlePropTypeFontTTF(pNode, pParent, pPropertyName, pFontTTF, pCCBReader);
    }
}

// =====================================================================
// CCBFileLoader
// =====================================================================

CCBFileLoader* CCBFileLoader::loader()
{
    auto* ret = new CCBFileLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCBFileLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    // 嵌套 CCB 文件的占位节点，由 CCBReader 在属性处理中替换
    return ax::Node::create();
}

// =====================================================================
// CCBFileNewLoader
// =====================================================================

CCBFileNewLoader* CCBFileNewLoader::loader()
{
    auto* ret = new CCBFileNewLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCBFileNewLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    // 新版嵌套 CCB 文件的占位节点
    return ax::Node::create();
}

// =====================================================================
// CCScrollViewLoader
// =====================================================================

CCScrollViewLoader* CCScrollViewLoader::loader()
{
    auto* ret = new CCScrollViewLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCScrollViewLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::ui::ScrollView::create();
}

void CCScrollViewLoader::onHandlePropTypeSize(ax::Node* pNode, ax::Node* pParent,
                                                const char* pPropertyName, ax::Size pSize,
                                                CCBReader* pCCBReader)
{
    if (strcmp(pPropertyName, PROPERTY_CONTENTSIZE) == 0) {
        auto* scrollView = dynamic_cast<ax::ui::ScrollView*>(pNode);
        if (scrollView) {
            scrollView->setContentSize(pSize);
        }
    } else {
        ASSERT_FAIL_UNEXPECTED_PROPERTY(pPropertyName);
    }
}

void CCScrollViewLoader::onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent,
                                                 const char* pPropertyName, float pFloat,
                                                 CCBReader* pCCBReader)
{
    CCNodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, pCCBReader);
}

void CCScrollViewLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                                 const char* pPropertyName, bool pCheck,
                                                 CCBReader* pCCBReader)
{
    CCNodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, pCCBReader);
}

void CCScrollViewLoader::onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent,
                                                   const char* pPropertyName,
                                                   ax::Node* pCCBFileNode,
                                                   CCBReader* pCCBReader)
{
    auto* scrollView = dynamic_cast<ax::ui::ScrollView*>(pNode);
    if (scrollView && pCCBFileNode) {
        // 将嵌套 CCB 文件节点设为 ScrollView 的内部容器子节点
        scrollView->addChild(pCCBFileNode);
        scrollView->setInnerContainerSize(pCCBFileNode->getContentSize());
    }
}

// =====================================================================
// CCParticleSystemQuadLoader
// =====================================================================

CCParticleSystemQuadLoader* CCParticleSystemQuadLoader::loader()
{
    auto* ret = new CCParticleSystemQuadLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCParticleSystemQuadLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::ParticleSystemQuad::create();
}

void CCParticleSystemQuadLoader::onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent,
                                                         const char* pPropertyName, float pFloat,
                                                         CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (!ps) return;

    if (strcmp(pPropertyName, "emissionRate") == 0) {
        ps->setEmissionRate(pFloat);
    } else if (strcmp(pPropertyName, "life") == 0) {
        ps->setLife(pFloat);
    } else if (strcmp(pPropertyName, "lifeVar") == 0) {
        ps->setLifeVar(pFloat);
    } else if (strcmp(pPropertyName, "angle") == 0) {
        ps->setAngle(pFloat);
    } else if (strcmp(pPropertyName, "angleVar") == 0) {
        ps->setAngleVar(pFloat);
    } else if (strcmp(pPropertyName, "speed") == 0) {
        ps->setSpeed(pFloat);
    } else if (strcmp(pPropertyName, "speedVar") == 0) {
        ps->setSpeedVar(pFloat);
    } else if (strcmp(pPropertyName, "gravity") == 0) {
        // gravity 需要两个分量，此处为简化
    } else if (strcmp(pPropertyName, "tangentialAccel") == 0) {
        ps->setTangentialAccel(pFloat);
    } else if (strcmp(pPropertyName, "tangentialAccelVar") == 0) {
        ps->setTangentialAccelVar(pFloat);
    } else if (strcmp(pPropertyName, "radialAccel") == 0) {
        ps->setRadialAccel(pFloat);
    } else if (strcmp(pPropertyName, "radialAccelVar") == 0) {
        ps->setRadialAccelVar(pFloat);
    } else if (strcmp(pPropertyName, "startSize") == 0) {
        ps->setStartSize(pFloat);
    } else if (strcmp(pPropertyName, "startSizeVar") == 0) {
        ps->setStartSizeVar(pFloat);
    } else if (strcmp(pPropertyName, "endSize") == 0) {
        ps->setEndSize(pFloat);
    } else if (strcmp(pPropertyName, "endSizeVar") == 0) {
        ps->setEndSizeVar(pFloat);
    } else if (strcmp(pPropertyName, "startSpin") == 0) {
        ps->setStartSpin(pFloat);
    } else if (strcmp(pPropertyName, "startSpinVar") == 0) {
        ps->setStartSpinVar(pFloat);
    } else if (strcmp(pPropertyName, "endSpin") == 0) {
        ps->setEndSpin(pFloat);
    } else if (strcmp(pPropertyName, "endSpinVar") == 0) {
        ps->setEndSpinVar(pFloat);
    } else {
        CCNodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, pCCBReader);
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypeInteger(ax::Node* pNode, ax::Node* pParent,
                                                           const char* pPropertyName, int pInteger,
                                                           CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (!ps) return;

    if (strcmp(pPropertyName, "totalParticles") == 0) {
        ps->setTotalParticles(pInteger);
    } else if (strcmp(pPropertyName, "blendFuncSource") == 0) {
        auto bf = ps->getBlendFunc();
        bf.src = static_cast<ax::rhi::BlendFactor>(pInteger);
        ps->setBlendFunc(bf);
    } else if (strcmp(pPropertyName, "blendFuncDestination") == 0) {
        auto bf = ps->getBlendFunc();
        bf.dst = static_cast<ax::rhi::BlendFactor>(pInteger);
        ps->setBlendFunc(bf);
    } else if (strcmp(pPropertyName, "emitterMode") == 0) {
        ps->setEmitterMode(static_cast<ax::ParticleSystem::Mode>(pInteger));
    } else {
        CCNodeLoader::onHandlePropTypeInteger(pNode, pParent, pPropertyName, pInteger, pCCBReader);
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypePoint(ax::Node* pNode, ax::Node* pParent,
                                                         const char* pPropertyName,
                                                         ax::Vec2 pPoint,
                                                         CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (!ps) return;

    if (strcmp(pPropertyName, "sourcePosition") == 0) {
        ps->setPosition(pPoint);
    } else if (strcmp(pPropertyName, "posVar") == 0) {
        ps->setPosVar(pPoint);
    } else if (strcmp(pPropertyName, "gravity") == 0) {
        ps->setGravity(pPoint);
    } else {
        CCNodeLoader::onHandlePropTypePoint(pNode, pParent, pPropertyName, pPoint, pCCBReader);
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypeColor3(ax::Node* pNode, ax::Node* pParent,
                                                          const char* pPropertyName,
                                                          ax::Color32 pColor3B,
                                                          CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (!ps) return;

    ax::Color color4F(pColor3B);

    if (strcmp(pPropertyName, "startColor") == 0) {
        ps->setStartColor(color4F);
    } else if (strcmp(pPropertyName, "endColor") == 0) {
        ps->setEndColor(color4F);
    } else {
        CCNodeLoader::onHandlePropTypeColor3(pNode, pParent, pPropertyName, pColor3B, pCCBReader);
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypeBlendmode(ax::Node* pNode, ax::Node* pParent,
                                                             const char* pPropertyName,
                                                             unsigned int pBlendmode,
                                                             CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (ps) {
        ax::BlendFunc blendFunc;
        blendFunc.src = static_cast<ax::rhi::BlendFactor>(pBlendmode >> 16);
        blendFunc.dst = static_cast<ax::rhi::BlendFactor>(pBlendmode & 0xFFFF);
        ps->setBlendFunc(blendFunc);
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypeTexture(ax::Node* pNode, ax::Node* pParent,
                                                           const char* pPropertyName,
                                                           ax::Texture2D* pTexture2D,
                                                           CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (ps && pTexture2D) {
        ps->setTexture(pTexture2D);
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypeSpriteFrame(ax::Node* pNode, ax::Node* pParent,
                                                               const char* pPropertyName,
                                                               ax::SpriteFrame* pSpriteFrame,
                                                               CCBReader* pCCBReader)
{
    auto* ps = dynamic_cast<ax::ParticleSystemQuad*>(pNode);
    if (ps && pSpriteFrame) {
        ps->setTexture(pSpriteFrame->getTexture());
        ps->setTextureWithRect(pSpriteFrame->getTexture(), pSpriteFrame->getRect());
    }
}

void CCParticleSystemQuadLoader::onHandlePropTypeByte(ax::Node* pNode, ax::Node* pParent,
                                                        const char* pPropertyName,
                                                        unsigned char pByte,
                                                        CCBReader* pCCBReader)
{
    CCNodeLoader::onHandlePropTypeByte(pNode, pParent, pPropertyName, pByte, pCCBReader);
}

// =====================================================================
// CCBClippingNodeLoader
// =====================================================================

CCBClippingNodeLoader* CCBClippingNodeLoader::loader()
{
    auto* ret = new CCBClippingNodeLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCBClippingNodeLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::ClippingNode::create();
}

void CCBClippingNodeLoader::onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName, float pFloat,
                                                    CCBReader* pCCBReader)
{
    auto* clipper = dynamic_cast<ax::ClippingNode*>(pNode);
    if (clipper) {
        if (strcmp(pPropertyName, "alphaThreshold") == 0) {
            clipper->setAlphaThreshold(pFloat);
        } else {
            CCNodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, pCCBReader);
        }
    }
}

void CCBClippingNodeLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                                    const char* pPropertyName, bool pCheck,
                                                    CCBReader* pCCBReader)
{
    auto* clipper = dynamic_cast<ax::ClippingNode*>(pNode);
    if (clipper) {
        if (strcmp(pPropertyName, "inverted") == 0) {
            clipper->setInverted(pCheck);
        } else {
            CCNodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, pCCBReader);
        }
    }
}

void CCBClippingNodeLoader::onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent,
                                                      const char* pPropertyName,
                                                      ax::Node* pCCBFileNode,
                                                      CCBReader* pCCBReader)
{
    auto* clipper = dynamic_cast<ax::ClippingNode*>(pNode);
    if (clipper && pCCBFileNode) {
        // 设置裁剪模板（stencil）
        clipper->setStencil(pCCBFileNode);
    }
}

void CCBClippingNodeLoader::onHandlePropTypeInteger(ax::Node* pNode, ax::Node* pParent,
                                                      const char* pPropertyName, int pInteger,
                                                      CCBReader* pCCBReader)
{
    CCNodeLoader::onHandlePropTypeInteger(pNode, pParent, pPropertyName, pInteger, pCCBReader);
}

// =====================================================================
// CCClippingNodeLoader
// =====================================================================

CCClippingNodeLoader* CCClippingNodeLoader::loader()
{
    auto* ret = new CCClippingNodeLoader();
    ret->autorelease();
    return ret;
}

ax::Node* CCClippingNodeLoader::createCCNode(ax::Node* pParent, CCBReader* pCCBReader)
{
    return ax::ClippingNode::create();
}

void CCClippingNodeLoader::onHandlePropTypeFloat(ax::Node* pNode, ax::Node* pParent,
                                                   const char* pPropertyName, float pFloat,
                                                   CCBReader* pCCBReader)
{
    auto* clipper = dynamic_cast<ax::ClippingNode*>(pNode);
    if (clipper) {
        if (strcmp(pPropertyName, "alphaThreshold") == 0) {
            clipper->setAlphaThreshold(pFloat);
        } else {
            CCNodeLoader::onHandlePropTypeFloat(pNode, pParent, pPropertyName, pFloat, pCCBReader);
        }
    }
}

void CCClippingNodeLoader::onHandlePropTypeCheck(ax::Node* pNode, ax::Node* pParent,
                                                   const char* pPropertyName, bool pCheck,
                                                   CCBReader* pCCBReader)
{
    auto* clipper = dynamic_cast<ax::ClippingNode*>(pNode);
    if (clipper) {
        if (strcmp(pPropertyName, "inverted") == 0) {
            clipper->setInverted(pCheck);
        } else {
            CCNodeLoader::onHandlePropTypeCheck(pNode, pParent, pPropertyName, pCheck, pCCBReader);
        }
    }
}

void CCClippingNodeLoader::onHandlePropTypeCCBFile(ax::Node* pNode, ax::Node* pParent,
                                                     const char* pPropertyName,
                                                     ax::Node* pCCBFileNode,
                                                     CCBReader* pCCBReader)
{
    auto* clipper = dynamic_cast<ax::ClippingNode*>(pNode);
    if (clipper && pCCBFileNode) {
        clipper->setStencil(pCCBFileNode);
    }
}

} // namespace ccb
