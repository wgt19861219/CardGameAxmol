#include "LegendAnimationFileInfo.h"
#include "axmol/axmol.h"

extern "C" {
#include "unzip/unzip.h"
}

namespace ax {

std::unordered_map<std::string, LegendAnimationFileInfo*> LegendAnimationFileInfo::_cache;

// ---- Binary reader helpers ----
static void readInt(unsigned char*& data, unsigned int& out)
{
    memcpy(&out, data, sizeof(unsigned int));
    data += sizeof(unsigned int);
}

static void readFloat(unsigned char*& data, float& out)
{
    memcpy(&out, data, sizeof(float));
    data += sizeof(float);
}

static void readString(unsigned char*& data, std::string& out)
{
    unsigned int sz = 0;
    readInt(data, sz);
    out.assign((char*)data, sz);
    data += sz;
}

static void readAffineTransform(unsigned char*& data, AffineTransform& out)
{
    memcpy(&out, data, sizeof(AffineTransform));
    data += sizeof(AffineTransform);
}

// ---- ZIP extraction ----
static bool extractFromZip(const std::string& zipPath, const std::string& entryName,
                           std::vector<unsigned char>& outData)
{
    unzFile zf = unzOpen(zipPath.c_str());
    if (!zf) return false;

    bool found = false;
    if (unzLocateFile(zf, entryName.c_str(), 0) == UNZ_OK)
    {
        unz_file_info info;
        unzGetCurrentFileInfo(zf, &info, nullptr, 0, nullptr, 0, nullptr, 0);

        if (unzOpenCurrentFile(zf) == UNZ_OK)
        {
            outData.resize(info.uncompressed_size);
            int bytesRead = unzReadCurrentFile(zf, outData.data(), info.uncompressed_size);
            unzCloseCurrentFile(zf);
            found = (bytesRead > 0);
        }
    }
    unzClose(zf);
    return found;
}

// ---- Factory ----
LegendAnimationFileInfo* LegendAnimationFileInfo::getAniFileInfo(const std::string& name)
{
    auto it = _cache.find(name);
    if (it != _cache.end())
        return it->second;

    auto* obj = new LegendAnimationFileInfo(name);
    if (obj->_elements.empty() && obj->_actions.empty())
    {
        delete obj;
        _cache[name] = nullptr;
        return nullptr;
    }
    _cache[name] = obj;
    obj->autorelease();  // cache holds it via Ref
    return obj;
}

// ---- Constructor ----
LegendAnimationFileInfo::LegendAnimationFileInfo(const std::string& name)
    : _name(name)
{
    auto* fu = FileUtils::getInstance();

    // Try .ani first, then .abc
    std::string filename = "anim/" + name + ".ani";
    std::string fullPath = fu->fullPathForFilename(filename);
    bool isCompatible = false;

    if (fullPath.empty() || fullPath == filename)
    {
        filename = "anim/" + name + ".abc";
        fullPath = fu->fullPathForFilename(filename);
        isCompatible = true;
        if (fullPath.empty() || fullPath == filename)
        {
            AXLOGW("LegendAnimationFileInfo: file not found: {}", name);
            return;
        }
    }

    _scalefactor = 1.0f;  // g_ani_scale_factor, default 1.0

    // Extract plist
    std::vector<unsigned char> plistData;
    std::string plistEntry = isCompatible ? "plist" : "sheet.plist";
    if (!extractFromZip(fullPath, plistEntry, plistData) || plistData.empty())
    {
        AXLOGW("LegendAnimationFileInfo: failed to extract plist from {}", filename);
        return;
    }

    // Extract texture (try PNG then PVR)
    std::vector<unsigned char> textureData;
    bool hasTexture = extractFromZip(fullPath, isCompatible ? "cha" : "sheet.png", textureData);
    if (!hasTexture || textureData.empty())
        hasTexture = extractFromZip(fullPath, "sheet.png", textureData);
    if (!hasTexture || textureData.empty())
        hasTexture = extractFromZip(fullPath, "sheet.pvr", textureData);
    if (!hasTexture || textureData.empty())
    {
        AXLOGW("LegendAnimationFileInfo: failed to extract texture from {}", filename);
        return;
    }

    // Create texture from image data
    auto* image = new Image();
    bool imageOk = image->initWithImageData(textureData.data(), textureData.size());
    if (!imageOk)
    {
        AXLOGW("LegendAnimationFileInfo: failed to init image");
        image->release();
        return;
    }

    auto textureName = name + "_ani_tex";
    auto* texture = Director::getInstance()->getTextureCache()->addImage(image, textureName);
    image->release();

    if (!texture)
    {
        AXLOGW("LegendAnimationFileInfo: failed to create texture");
        return;
    }

    // Load sprite frames from plist content
    Data plistContent;
    plistContent.copy(plistData.data(), plistData.size());
    SpriteFrameCache::getInstance()->addSpriteFramesWithFileContent(plistContent, texture);

    // Extract and parse key file
    std::vector<unsigned char> keyData;
    std::string keyEntry = isCompatible ? "cha" : "sheet.key";
    if (!extractFromZip(fullPath, keyEntry, keyData) && !isCompatible)
        keyEntry = "sheet.key";
    if (!keyData.empty())
    {
        readFrames(this, keyData.data(), keyData.size());
    }
}

LegendAnimationFileInfo::~LegendAnimationFileInfo()
{
    _actions.clear();
    _elements.clear();
}

SpriteFrame* LegendAnimationFileInfo::getSpriteFrame(const char* frameName)
{
    std::string fullName = std::string(frameName) + ".png";
    return SpriteFrameCache::getInstance()->getSpriteFrameByName(fullName);
}

void LegendAnimationFileInfo::readFrames(LegendAnimationFileInfo* info, unsigned char* data, unsigned long dataSize)
{
    unsigned char* pdataEnd = data + dataSize;
    float factor = 1.0f / info->_scalefactor;

    readString(data, info->_name);

    // Read elements
    unsigned int elementCount = 0;
    readInt(data, elementCount);
    info->_elements.resize(elementCount);

    for (unsigned int i = 0; i < elementCount; i++)
    {
        LegendAnimationElement& ele = info->_elements[i];
        readString(data, ele.layerName);
        readString(data, ele.resouceName);
        readInt(data, ele.index);

        SpriteFrame* frame = info->getSpriteFrame(ele.resouceName.c_str());
        if (frame)
        {
            ele.width  = frame->getOriginalSize().width;
            ele.height = frame->getOriginalSize().height;
        }
    }

    // Read actions
    unsigned int actionCount = 0;
    readInt(data, actionCount);
    info->_actions.resize(actionCount);

    for (unsigned int i = 0; i < actionCount; i++)
    {
        LegendAnimationAction& action = info->_actions[i];
        readString(data, action.name);
        readFloat(data, action.fps);

        unsigned int frameCount = 0;
        readInt(data, frameCount);
        action.frames.resize(frameCount);

        for (unsigned int j = 0; j < frameCount; j++)
        {
            LegendAnimationFrame& frame = action.frames[j];

            // Events
            unsigned int eventCount = 0;
            readInt(data, eventCount);
            frame.events.resize(eventCount);

            for (unsigned int k = 0; k < eventCount; k++)
            {
                LegendAnimationEvent& evt = frame.events[k];
                readInt(data, evt.type);
                readString(data, evt.arg);
                readFloat(data, evt.x1);
                readFloat(data, evt.x2);
                readAffineTransform(data, evt.transform);
                unsigned int z;
                readInt(data, z);
                evt.zorder = (int)z;
            }

            // Frame elements
            unsigned int felemCount = 0;
            readInt(data, felemCount);
            frame.elements.resize(felemCount);

            for (unsigned int k = 0; k < felemCount; k++)
            {
                LegendAnimationFrameElement& felem = frame.elements[k];
                felem.index = *(unsigned short*)data;
                data += 2;
                felem.alpha = *data;
                data += 1;
                readAffineTransform(data, felem.transform);

                // Transform adjustment (matches original engine)
                if (felem.index > 0 && felem.index <= info->_elements.size())
                {
                    float dstA = felem.transform.a * factor;
                    float dstB = felem.transform.b * factor;
                    float dstC = felem.transform.c * factor;
                    float dstD = felem.transform.d * factor;
                    float fwidth  = info->_elements[felem.index - 1].width;
                    float fheight = info->_elements[felem.index - 1].height;
                    float dstTX = (dstC * fheight * 0.5f - dstA * 0.5f * fwidth) + felem.transform.tx;
                    float dstTY = (dstD * -0.5f * fheight + dstB * 0.5f * fwidth) - felem.transform.ty;
                    felem.transform = AffineTransformMake(dstA, -dstB, -dstC, dstD, dstTX, dstTY);
                }
            }
        }
    }

    if (pdataEnd != data)
    {
        AXLOGW("LegendAnimationFileInfo: readFrames size mismatch for {}, remaining {} bytes",
               info->_name, (int)(pdataEnd - data));
    }
}

} // namespace ax
