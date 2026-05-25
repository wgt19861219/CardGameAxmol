#include "SpineContainer.h"
#include "axmol/audio/AudioEngine.h"

#define TIMES_SPINE_LOOP -1

int SpineContainer::s_soundSwitch = 1;

SpineContainer::SpineContainer()
    : SkeletonAnimation()
    , GameAnimation(Type_Spine)
    , m_pEventListener(nullptr)
    , m_iLuaListener(0)
    , m_bIsLoop(false)
    , m_sCurrAniName("")
    , _curSoundId(0)
    , _isSoundPlay(false)
    , m_iCurrEffectTag(0)
{
}

SpineContainer::~SpineContainer()
{
    _isDestroying = true;
    clearTracks();
    m_mapTrack.clear();
}

SpineContainer* SpineContainer::create(const char* path, const char* name, float scale)
{
    if (!path || !name) return nullptr;

    std::string filePath = std::string(path) + "/" + std::string(name);
    std::string configFile = filePath + ".json";
    std::string atlasFile = filePath + ".atlas";

    // Check if files exist before trying to load
    auto* fu = ax::FileUtils::getInstance();
    if (!fu->isFileExist(configFile) || !fu->isFileExist(atlasFile)) {
        AXLOGW("SpineContainer: missing files config={} atlas={}", configFile, atlasFile);
        return nullptr;
    }

    // Pre-check Spine version: read "spine":"X.Y.Z" from JSON
    // Spine runtime 4.x cannot load 2.x data - return nullptr, Lua fallback will create static sprite
 {
        std::string jsonContent = fu->getStringFromFile(configFile);
        if (jsonContent.find("\"spine\":\"2.") != std::string::npos ||
            jsonContent.find("\"spine\": \"2.") != std::string::npos) {
            AXLOGI("SpineContainer: {} is spine 2.x data, falling back to static sprite (4.x runtime incompatible)", filePath);
            return nullptr;
        }
    }

    auto* ret = new SpineContainer();
    if (!ret) return nullptr;

    ret->initWithJsonFile(configFile, atlasFile, scale);
    ret->autorelease();
    return ret;
}

void SpineContainer::runAnimation(int trackIndex, const char* name, int loopTimes, float delay)
{
    if (loopTimes == 0 || loopTimes < TIMES_SPINE_LOOP)
        return;

    --loopTimes;

    auto it = m_mapTrack.find(name);
    if (it == m_mapTrack.end())
    {
        m_mapTrack.insert(std::make_pair(name, SAnimationInfo(name, trackIndex, loopTimes)));
    }
    else
    {
        trackIndex = it->second.trackIndex;
        it->second.loopTimes = loopTimes;
    }

    spine::TrackEntry* aniEntry = nullptr;
    if (delay != 0.0f)
    {
        aniEntry = addAnimation(trackIndex, name, loopTimes != 0, delay);
    }
    else
    {
        aniEntry = setAnimation(trackIndex, name, loopTimes != 0);
        m_sCurrAniName = name;
    }

    if (aniEntry)
    {
        // Axmol Spine 使用 std::function 回调，而非 selector
        // 使用 weak 引用守卫：析构时 clearTracks() 会先清除回调
        setTrackStartListener(aniEntry, [this](spine::TrackEntry* entry) {
            if (_isDestroying) return;
            onReceiveStartEventListener(entry->getTrackIndex(),
                entry->getAnimation() ? entry->getAnimation()->getName().buffer() : "");
        });
        setTrackEndListener(aniEntry, [this](spine::TrackEntry* entry) {
            if (_isDestroying) return;
            onReceiveEndEventListener(entry->getTrackIndex(),
                entry->getAnimation() ? entry->getAnimation()->getName().buffer() : "");
        });
        setTrackCompleteListener(aniEntry, [this](spine::TrackEntry* entry) {
            if (_isDestroying) return;
            onReceiveCompleteEventListener(entry->getTrackIndex(),
                entry->getAnimation() ? entry->getAnimation()->getName().buffer() : "",
                0);
        });
        setTrackEventListener(aniEntry, [this](spine::TrackEntry* entry, spine::Event* event) {
            if (_isDestroying) return;
            onReceiveEventListener(entry->getTrackIndex(),
                entry->getAnimation() ? entry->getAnimation()->getName().buffer() : "",
                event);
        });
    }
}

void SpineContainer::setListener(SpineEventListener* eventListener)
{
    m_pEventListener = eventListener;
}

void SpineContainer::registerLuaListener(int listener)
{
    m_iLuaListener = listener;
}

void SpineContainer::unregisterLuaListener()
{
    m_iLuaListener = 0;
}

void SpineContainer::stopAllAnimations()
{
    clearTracks();
}

void SpineContainer::stopAnimationByIndex(int trackIndex)
{
    clearTrack(trackIndex);
}

void SpineContainer::onReceiveStartEventListener(int trackIndex, const std::string& animationName)
{
    if (m_pEventListener)
        m_pEventListener->onSpineAnimationStart(trackIndex, animationName);
}

void SpineContainer::onReceiveEndEventListener(int trackIndex, const std::string& animationName)
{
    if (m_pEventListener)
        m_pEventListener->onSpineAnimationEnd(trackIndex, animationName);
}

void SpineContainer::onReceiveCompleteEventListener(int trackIndex, const std::string& animationName, int loopCount)
{
    if (m_pEventListener)
        m_pEventListener->onSpineAnimationComplete(trackIndex, animationName, loopCount);
    onActionFinished();
}

void SpineContainer::onReceiveEventListener(int trackIndex, const std::string& animationName, spine::Event* event)
{
    if (m_pEventListener)
        m_pEventListener->onSpineAnimationEvent(trackIndex, animationName, event);

    if (event && s_soundSwitch)
    {
        // Spine 4.x Event API
        auto& data = event->getData();
        auto intValue = event->getIntValue();
        if (intValue == 1)
        {
            auto& soundStr = event->getStringValue();
            std::string soundFile = "sound/" + std::string(soundStr.buffer());
            _curSoundId = ax::AudioEngine::play2d(soundFile);
            _isSoundPlay = true;
        }
    }
}

bool SpineContainer::setAction(const char* name, bool bRemoveQueue)
{
    if (!name) return false;
    runAnimation(0, name, 1);
    if (bRemoveQueue)
        clearActionSequence();
    return true;
}

void SpineContainer::setNextAction(const char* actionName)
{
    if (!actionName) return;
    _actionQueue.insert(_actionQueue.begin(), std::string(actionName));
}

void SpineContainer::onActionFinished()
{
    if (!_actionQueue.empty())
    {
        std::string str = _actionQueue.front();
        setAction(str.c_str(), false);
        _actionQueue.erase(_actionQueue.begin());
    }
    else if (m_bIsLoop && !m_sCurrAniName.empty())
    {
        runAnimation(0, m_sCurrAniName.c_str(), TIMES_SPINE_LOOP);
    }
    else
    {
        m_sCurrAniName = "";
    }
}

void SpineContainer::clearActionSequence()
{
    _actionQueue.clear();
}

int SpineContainer::addEffect(const char* resName)
{
    return addEffect(resName, ax::AffineTransform::IDENTITY, 1);
}

int SpineContainer::addEffect(const char* resName, const ax::AffineTransform& mat, int zorder)
{
    // 简化实现：创建 Sprite 作为特效节点
    auto* spr = ax::Sprite::create(resName);
    if (!spr) return -1;

    spr->setPosition(ax::Vec2(mat.tx, mat.ty));
    this->addChild(spr, zorder);
    _effectArray.pushBack(spr);
    spr->setTag(m_iCurrEffectTag++);
    return spr->getTag();
}

int SpineContainer::addEffect(const char* resName, ax::Vec2 pos, int zorder)
{
    auto mt = ax::AffineTransform::IDENTITY;
    mt.tx = pos.x;
    mt.ty = pos.y;
    return addEffect(resName, mt, zorder);
}

int SpineContainer::addEffect(const char* resName, int zorder)
{
    return addEffect(resName, ax::AffineTransform::IDENTITY, zorder);
}

void SpineContainer::removeEffectWithID(int eid)
{
    for (auto it = _effectArray.begin(); it != _effectArray.end(); ++it)
    {
        if ((*it)->getTag() == eid)
        {
            this->removeChild(*it, true);
            _effectArray.erase(it);
            return;
        }
    }
}

void SpineContainer::removeEffectWithName(const char* eff)
{
    if (!eff) return;
    std::string effStr(eff);
    for (auto it = _effectArray.begin(); it != _effectArray.end(); ++it)
    {
        if ((*it)->getName() == effStr)
        {
            this->removeChild(*it, true);
            _effectArray.erase(it);
            return;
        }
    }
    AXLOGW("SpineContainer::removeEffectWithName '{}' not found", eff);
}

void SpineContainer::update(float dt, bool isAuto)
{
    // 无论自动/手动模式，骨骼动画都需要 update
    SkeletonAnimation::update(dt);

    // 手动模式下额外处理特效生命周期
    if (!isAuto)
    {
        for (int i = (int)_effectArray.size() - 1; i >= 0; --i)
        {
            auto* node = _effectArray.at(i);
            if (node && node->getReferenceCount() <= 1)
            {
                _effectArray.erase(_effectArray.begin() + i);
            }
        }
    }
}

void SpineContainer::tint(float r, float g, float b)
{
    // Spine SkeletonAnimation 的 tint 在 Axmol 中的实现
    setColor(ax::Color32((unsigned char)(r * 255), (unsigned char)(g * 255), (unsigned char)(b * 255)));
}

void SpineContainer::setColor(ax::Color32 clr)
{
    ax::Node::setColor(clr);
    for (auto& spr : _effectArray)
    {
        spr->setColor(clr);
    }
}

void SpineContainer::setOpacity(unsigned char param1)
{
    ax::Node::setOpacity(param1);
    for (auto& spr : _effectArray)
    {
        spr->setOpacity(param1);
    }
}

void SpineContainer::useDefaultShader()
{
    // Axmol 使用不同的 shader 系统
    // 暂时使用默认 shader
}

void SpineContainer::useShader(const char* shaderName)
{
    // Axmol shader 系统与 cocos2d-x 2.x 完全不同
    // 后续需要用 Axmol 的 backend::Program 实现
}

void SpineContainer::interruptSound()
{
    if (_isSoundPlay)
    {
        ax::AudioEngine::stop(_curSoundId);
        _curSoundId = 0;
        _isSoundPlay = false;
    }
}
