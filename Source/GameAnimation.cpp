#include "GameAnimation.h"

GameAnimation::GameAnimation(AnimationType aniType)
    : mAniType(aniType)
{
}

GameAnimation::~GameAnimation() {}

GameAnimation* GameAnimation::create(const char* resource, double scale, AnimationType aniType)
{
    // Factory delegates to concrete type
    return nullptr;  // Should not be called directly
}
