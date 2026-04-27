#pragma once

#include "axmol/axmol.h"
#include "LegendAnimationFileInfo.h"

namespace ax {

class SpriteBatchNode;

class LegendAnimationEffect;

class LegendAnimation : public Sprite
{
public:
    static LegendAnimation* create(const char* resource, double scale = 1.0);
    virtual ~LegendAnimation();

    bool setAction(const char* name, bool bRemoveQueue = true);
    void setNextAction(const char* actionName);
    void setLoop(bool val);
    void setActionElapsed(float elapsed);
    void setActionSpeeder(float speeder);
    bool isTerminated() const { return _isTerminated; }
    std::string getAniFileName() const { return _aniFileName; }
    float getActionNaturalDuration() const;

    // Effect management (matches original LegendAnimation)
    int addEffect(const char* resName);
    int addEffect(const char* resName, const AffineTransform& mat, int zorder);
    int addEffect(const char* resName, Vec2 pos, int zorder);
    int addEffect(const char* resName, int zorder);
    void removeEffectWithID(int eid);
    void removeEffectWithName(const char* name);

    virtual void update(float dt) override;

protected:
    LegendAnimation();
    bool init(LegendAnimationFileInfo* info, double scale);
    virtual void onActionFinished();
    void applyFrame(const LegendAnimationFrame& frame);

    LegendAnimationFileInfo* _aniFileInfo = nullptr;
    std::string _aniFileName;

    // Batch rendering (matches original CCSpriteBatchNode architecture)
    SpriteBatchNode* _batchNode = nullptr;
    std::vector<Sprite*> _elementSprites;

    // Effect management (matches original _effectArray)
    Vector<LegendAnimationEffect*> _effectArray;
    int _curEffectTag = 0;

    int _currentFrame = -1;
    std::string _currentActionName;
    const LegendAnimationAction* _currentAction = nullptr;
    std::string _nextActionName;
    bool _isLoop = false;
    float _curActionElapsed = 0;
    float _speeder = 1.0f;
    float _frameDuration = 0;
    bool _isTerminated = false;
    bool _externalTimeCtrl = false;  // true = Lua controls elapsed, update() skips auto-accumulate
    bool _externalPositioning = false; // true = applyFrame centers children at origin, skips animation transforms

public:
    void setExternalPositioning(bool val) { _externalPositioning = val; }
};

// ---- LegendAnimationEffect (Start → Loop auto-switch) ----

class LegendAnimationEffect : public LegendAnimation
{
public:
    static LegendAnimationEffect* create(const char* resource);
    virtual ~LegendAnimationEffect();

    void setLoopAction(const char* actionName);
    void setStartAction(const char* actionName);

    virtual void onEnter() override;
    virtual void update(float dt) override;

protected:
    LegendAnimationEffect();

    std::string _startActionName = "Start";
    std::string _loopActionName = "Loop";
};

} // namespace ax
