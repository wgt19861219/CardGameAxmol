#pragma once

#include "axmol/axmol.h"
#include <vector>
#include <string>
#include <unordered_map>

namespace ax {

// ---- Animation data structures ----

struct LegendAnimationEvent
{
    enum EventType
    {
        EVENT_SOUND = 1,
        EVENT_ADD_EFFECT = 2,
        EVENT_REMOVE_EFFECT = 3
    };

    unsigned int type = 0;
    std::string arg;
    float x1 = 0, x2 = 0;
    AffineTransform transform = {1, 0, 0, 1, 0, 0};
    int zorder = 0;
};

struct LegendAnimationFrameElement
{
    unsigned short index = 0;    // 1-based
    unsigned char alpha = 255;
    AffineTransform transform = {1, 0, 0, 1, 0, 0};
};

struct LegendAnimationFrame
{
    std::vector<LegendAnimationEvent> events;
    std::vector<LegendAnimationFrameElement> elements;
};

struct LegendAnimationAction
{
    std::string name;
    float fps = 30.0f;
    std::vector<LegendAnimationFrame> frames;
};

struct LegendAnimationElement
{
    std::string layerName;
    std::string resouceName;
    unsigned int index = 0;
    float width = 0;
    float height = 0;
};

// ---- Cached animation file info ----
// Each instance owns a PRIVATE sprite frame map (matching original cocos2d-x
// architecture where each character had its own CCSpriteFrameCache instance).
// This prevents frame name collisions between different .ani files that share
// generic names like "1.png", "Eyes.png", etc.

class LegendAnimationFileInfo : public Object
{
public:
    static LegendAnimationFileInfo* getAniFileInfo(const std::string& name);
    virtual ~LegendAnimationFileInfo();

    SpriteFrame* getSpriteFrame(const char* frameName);
    Texture2D* getTexture() const { return _texture; }
    float getScaleFactor() const { return _scalefactor; }

    // Global scale factor set by Lua (LegendSetAniScaleFactor)
    static void setCurrentScaleFactor(double factor) { s_currentScaleFactor = (float)factor; }
    static float getCurrentScaleFactor() { return s_currentScaleFactor; }

    std::string _name;
    float _scalefactor = 1.0f;
    std::vector<LegendAnimationElement> _elements;
    std::vector<LegendAnimationAction> _actions;

private:
    LegendAnimationFileInfo(const std::string& name);
    static void readFrames(LegendAnimationFileInfo* info, unsigned char* data, unsigned long dataSize);
    void parsePlistAndCreateFrames(const std::vector<unsigned char>& plistData, Texture2D* texture);

    // Private sprite frame storage — avoids global cache name collisions
    std::unordered_map<std::string, SpriteFrame*> _spriteFrames;
    Texture2D* _texture = nullptr;

    static std::unordered_map<std::string, LegendAnimationFileInfo*> _cache;
    static float s_currentScaleFactor;  // Set by LegendSetAniScaleFactor
};

} // namespace ax
