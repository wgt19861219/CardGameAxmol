#include "GameAnimation.h"

GameAnimation::GameAnimation(AnimationType aniType)
    : mAniType(aniType)
{
}

GameAnimation::~GameAnimation() {}

GameAnimation* GameAnimation::create(const char* resource, double scale, AnimationType aniType)
{
    // 工厂方法，由子类实现
    return nullptr;
}
