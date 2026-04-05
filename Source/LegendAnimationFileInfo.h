#pragma once

#include "axmol/axmol.h"
#include <vector>
#include <string>
#include <unordered_map>

namespace ax {

// ---- Animation data structures ----

struct LegendAnimationEvent
{
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

class SpriteFrameCache;

class LegendAnimationFileInfo : public Object
{
public:
    static LegendAnimationFileInfo* getAniFileInfo(const std::string& name);
    virtual ~LegendAnimationFileInfo();

    SpriteFrame* getSpriteFrame(const char* frameName);

    std::string _name;
    float _scalefactor = 1.0f;
    std::vector<LegendAnimationElement> _elements;
    std::vector<LegendAnimationAction> _actions;

private:
    LegendAnimationFileInfo(const std::string& name);
    static void readFrames(LegendAnimationFileInfo* info, unsigned char* data, unsigned long dataSize);

    SpriteFrameCache* _spriteCache = nullptr;
    static std::unordered_map<std::string, LegendAnimationFileInfo*> _cache;
};

} // namespace ax
