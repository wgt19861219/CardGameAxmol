#include "LegendAnimationFileInfo.h"
#include "axmol/axmol.h"

extern "C" {
#include "unzip/unzip.h"
#include <zlib.h>
}

namespace ax {

std::unordered_map<std::string, LegendAnimationFileInfo*> LegendAnimationFileInfo::_cache;
float LegendAnimationFileInfo::s_currentScaleFactor = 1.0f;

// ---- Binary reader helpers ----
static unsigned char* s_pdataEnd = nullptr;

static void readInt(unsigned char*& data, unsigned int& out)
{
    if (data + sizeof(unsigned int) > s_pdataEnd) { out = 0; return; }
    memcpy(&out, data, sizeof(unsigned int));
    data += sizeof(unsigned int);
}

static void readFloat(unsigned char*& data, float& out)
{
    if (data + sizeof(float) > s_pdataEnd) { out = 0; return; }
    memcpy(&out, data, sizeof(float));
    data += sizeof(float);
}

static void readString(unsigned char*& data, std::string& out)
{
    unsigned int sz = 0;
    readInt(data, sz);
    if (data + sz > s_pdataEnd) { out.clear(); return; }
    out.assign((char*)data, sz);
    data += sz;
}

static void readAffineTransform(unsigned char*& data, AffineTransform& out)
{
    if (data + sizeof(AffineTransform) > s_pdataEnd) { out = {1,0,0,1,0,0}; return; }
    memcpy(&out, data, sizeof(AffineTransform));
    data += sizeof(AffineTransform);
}

// ---- In-memory ZIP extraction ----

#pragma pack(push, 1)
struct ZipLocalFileHeader
{
    uint32_t signature;
    uint16_t versionNeeded;
    uint16_t generalFlag;
    uint16_t compressionMethod;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compressedSize;
    uint32_t uncompressedSize;
    uint16_t filenameLength;
    uint16_t extraFieldLength;
};
#pragma pack(pop)

static bool extractFromMemoryZip(const unsigned char* zipData, size_t zipSize,
                                  const std::string& entryName,
                                  std::vector<unsigned char>& outData)
{
    const unsigned char* ptr = zipData;
    const unsigned char* end = zipData + zipSize;

    while (ptr + sizeof(ZipLocalFileHeader) <= end)
    {
        auto* hdr = reinterpret_cast<const ZipLocalFileHeader*>(ptr);
        if (hdr->signature != 0x04034b50)
            break;

        const char* filename = reinterpret_cast<const char*>(ptr + sizeof(ZipLocalFileHeader));
        size_t nameLen = hdr->filenameLength;

        const unsigned char* dataStart = ptr + sizeof(ZipLocalFileHeader) + hdr->filenameLength + hdr->extraFieldLength;

        if (nameLen == entryName.size() &&
            memcmp(filename, entryName.c_str(), nameLen) == 0)
        {
            if (hdr->compressionMethod == 0)
            {
                if (dataStart + hdr->uncompressedSize <= end)
                {
                    outData.assign(dataStart, dataStart + hdr->uncompressedSize);
                    return true;
                }
            }
            else if (hdr->compressionMethod == 8)
            {
                outData.resize(hdr->uncompressedSize);
                z_stream stream = {};
                stream.next_in = const_cast<unsigned char*>(dataStart);
                stream.avail_in = hdr->compressedSize;
                stream.next_out = outData.data();
                stream.avail_out = hdr->uncompressedSize;

                if (inflateInit2(&stream, -MAX_WBITS) == Z_OK)
                {
                    int ret = inflate(&stream, Z_FINISH);
                    inflateEnd(&stream);
                    if (ret == Z_STREAM_END || ret == Z_OK)
                    {
                        outData.resize(stream.total_out);
                        return true;
                    }
                }
                outData.clear();
                return false;
            }
            return false;
        }

        size_t entrySize = sizeof(ZipLocalFileHeader) + hdr->filenameLength + hdr->extraFieldLength + hdr->compressedSize;
        if (hdr->generalFlag & 0x08)
        {
            if (hdr->compressedSize == 0)
            {
                const unsigned char* scan = dataStart;
                while (scan + 4 <= end)
                {
                    uint32_t sig;
                    memcpy(&sig, scan, sizeof(uint32_t));
                    if (sig == 0x04034b50 || sig == 0x02014b50 || sig == 0x06054b50)
                        break;
                    scan++;
                }
                ptr = scan;
                continue;
            }
        }
        ptr += entrySize;
    }
    return false;
}

static bool extractFromZip(const std::string& zipPath, const std::string& entryName,
                           std::vector<unsigned char>& outData)
{
    unzFile zf = unzOpen(zipPath.c_str());
    if (zf)
    {
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
        if (found) return true;
    }

    auto* fu = FileUtils::getInstance();
    auto zipData = fu->getDataFromFile(zipPath);
    if (zipData.isNull() || zipData.getSize() == 0)
        return false;

    return extractFromMemoryZip(reinterpret_cast<const unsigned char*>(zipData.getBytes()),
                                zipData.getSize(), entryName, outData);
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
        return nullptr;
    }
    obj->retain();
    _cache[name] = obj;
    return obj;
}

// ---- Constructor ----
LegendAnimationFileInfo::LegendAnimationFileInfo(const std::string& name)
    : _name(name)
{
    auto* fu = FileUtils::getInstance();

    // Search paths: anim/ root, then anim/effect/ subdirectory
    const char* searchPaths[] = { "anim/", "anim/effect/" };

    std::string filename;
    std::string fullPath;
    bool isCompatible = false;
    bool found = false;

    for (const char* basePath : searchPaths)
    {
        // Try .ani first
        filename = std::string(basePath) + name + ".ani";
        fullPath = fu->fullPathForFilename(filename);
        if (!fullPath.empty() && fullPath != filename)
        {
            found = true;
            break;
        }

        // Try .abc
        filename = std::string(basePath) + name + ".abc";
        fullPath = fu->fullPathForFilename(filename);
        if (!fullPath.empty() && fullPath != filename)
        {
            isCompatible = true;
            found = true;
            break;
        }
    }

    if (!found)
    {
        AXLOGW("LegendAnimationFileInfo: file not found: {}", name);
        return;
    }

    _scalefactor = s_currentScaleFactor;
    AXLOGW("LegendAnimationFileInfo ctor: name={}, scaleFactor={}, s_currentScaleFactor={}",
           name, _scalefactor, s_currentScaleFactor);

    // Extract plist
    std::vector<unsigned char> plistData;
    std::string plistEntry = isCompatible ? "plist" : "sheet.plist";
    if (!extractFromZip(fullPath, plistEntry, plistData) || plistData.empty())
    {
        AXLOGW("LegendAnimationFileInfo: failed to extract plist from {}", filename);
        return;
    }

    // Extract texture
    // .ani files: texture is in "sheet.png" (then fallback "sheet.pvr")
    // .abc files: texture is in "sheet.pvr" (NOT "cha" — "cha" is key frame data)
    std::vector<unsigned char> textureData;
    bool hasTexture = false;
    if (isCompatible)
    {
        // .abc format: texture is PVR
        hasTexture = extractFromZip(fullPath, "sheet.pvr", textureData);
        if (!hasTexture || textureData.empty())
            hasTexture = extractFromZip(fullPath, "sheet.png", textureData);
    }
    else
    {
        // .ani format: texture is PNG
        hasTexture = extractFromZip(fullPath, "sheet.png", textureData);
        if (!hasTexture || textureData.empty())
            hasTexture = extractFromZip(fullPath, "sheet.pvr", textureData);
    }
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
    _texture = Director::getInstance()->getTextureCache()->addImage(image, textureName);
    image->release();

    if (!_texture)
    {
        AXLOGW("LegendAnimationFileInfo: failed to create texture");
        return;
    }

    AXLOGW("LegendAnimationFileInfo: name={} textureSize={}x{}", name,
           (int)_texture->getContentSize().width, (int)_texture->getContentSize().height);

    // Parse plist and create sprite frames into PRIVATE map
    // This matches the original architecture where each LegendAnimationFileInfo
    // had its own CCSpriteFrameCache instance, preventing name collisions
    parsePlistAndCreateFrames(plistData, _texture);

    // Verify first sprite frame
    if (!_elements.empty())
    {
        auto* testFrame = getSpriteFrame(_elements[0].resouceName.c_str());
        if (testFrame)
        {
            auto r = testFrame->getRect();
            AXLOGW("LegendAnimationFileInfo: first frame '{}' rect=({},{},{},{})",
                   _elements[0].resouceName, (int)r.origin.x, (int)r.origin.y, (int)r.size.width, (int)r.size.height);
        }
        else
        {
            AXLOGW("LegendAnimationFileInfo: first frame '{}' NOT FOUND in private cache", _elements[0].resouceName);
        }
    }

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
    // Release all privately-owned sprite frames
    for (auto& [name, frame] : _spriteFrames)
    {
        if (frame)
            frame->release();
    }
    _spriteFrames.clear();

    // Texture is owned by TextureCache, don't release it here
    _texture = nullptr;

    _actions.clear();
    _elements.clear();
}

SpriteFrame* LegendAnimationFileInfo::getSpriteFrame(const char* frameName)
{
    // Look up in PRIVATE map (not global SpriteFrameCache)
    std::string fullName = std::string(frameName) + ".png";
    auto it = _spriteFrames.find(fullName);
    if (it != _spriteFrames.end())
        return it->second;
    return nullptr;
}

void LegendAnimationFileInfo::parsePlistAndCreateFrames(const std::vector<unsigned char>& plistData, Texture2D* texture)
{
    // Parse plist XML into ValueMap using Axmol's built-in parser
    auto dict = FileUtils::getInstance()->getValueMapFromData(
        reinterpret_cast<const char*>(plistData.data()),
        static_cast<int>(plistData.size()));

    if (dict.find("frames") == dict.end() || dict["frames"].getType() != Value::Type::MAP)
    {
        AXLOGW("LegendAnimationFileInfo: plist has no 'frames' dict");
        return;
    }

    auto& framesDict = dict["frames"].asValueMap();

    // Detect plist format from metadata
    int format = 0;
    auto metaIt = dict.find("metadata");
    if (metaIt != dict.end())
    {
        auto& metadata = metaIt->second.asValueMap();
        auto fmtIt = metadata.find("format");
        if (fmtIt != metadata.end())
            format = fmtIt->second.asInt();
    }

    AXLOGW("LegendAnimationFileInfo: parsing {} frames, format={}", framesDict.size(), format);

    // Create SpriteFrame objects from plist data (same logic as PlistSpriteSheetLoader)
    for (auto& [spriteFrameName, value] : framesDict)
    {
        auto& frameDict = value.asValueMap();
        SpriteFrame* spriteFrame = nullptr;

        if (format == 0)
        {
            float x  = frameDict.count("x") ? frameDict.at("x").asFloat() : 0;
            float y  = frameDict.count("y") ? frameDict.at("y").asFloat() : 0;
            float w  = frameDict.count("width") ? frameDict.at("width").asFloat() : 0;
            float h  = frameDict.count("height") ? frameDict.at("height").asFloat() : 0;
            float ox = frameDict.count("offsetX") ? frameDict.at("offsetX").asFloat() : 0;
            float oy = frameDict.count("offsetY") ? frameDict.at("offsetY").asFloat() : 0;
            int ow   = frameDict.count("originalWidth") ? abs(frameDict.at("originalWidth").asInt()) : 0;
            int oh   = frameDict.count("originalHeight") ? abs(frameDict.at("originalHeight").asInt()) : 0;
            if (!ow) ow = (int)w;
            if (!oh) oh = (int)h;
            spriteFrame = SpriteFrame::createWithTexture(texture, Rect(x, y, w, h), false, Vec2(ox, oy), Vec2((float)ow, (float)oh));
        }
        else if (format == 1 || format == 2)
        {
            Rect frame = utils::parseRect(frameDict.count("frame") ? frameDict.at("frame").asString() : "{{0,0},{0,0}}");
            bool rotated = (format == 2 && frameDict.count("rotated")) ? frameDict.at("rotated").asBool() : false;
            Vec2 offset = utils::parseVec2(frameDict.count("offset") ? frameDict.at("offset").asString() : "{0,0}");
            Vec2 sourceSize = utils::parseVec2(frameDict.count("sourceSize") ? frameDict.at("sourceSize").asString() : "{0,0}");
            spriteFrame = SpriteFrame::createWithTexture(texture, frame, rotated, offset, sourceSize);
        }
        else if (format == 3)
        {
            Vec2 spriteSize = utils::parseVec2(frameDict.count("spriteSize") ? frameDict.at("spriteSize").asString() : "{0,0}");
            Vec2 spriteOffset = utils::parseVec2(frameDict.count("spriteOffset") ? frameDict.at("spriteOffset").asString() : "{0,0}");
            Vec2 spriteSourceSize = utils::parseVec2(frameDict.count("spriteSourceSize") ? frameDict.at("spriteSourceSize").asString() : "{0,0}");
            Rect textureRect = utils::parseRect(frameDict.count("textureRect") ? frameDict.at("textureRect").asString() : "{{0,0},{0,0}}");
            bool textureRotated = frameDict.count("textureRotated") ? frameDict.at("textureRotated").asBool() : false;
            spriteFrame = SpriteFrame::createWithTexture(
                texture, Rect(textureRect.origin.x, textureRect.origin.y, spriteSize.width, spriteSize.height),
                textureRotated, spriteOffset, spriteSourceSize);
        }

        if (spriteFrame)
        {
            spriteFrame->retain();  // Private ownership
            _spriteFrames[spriteFrameName] = spriteFrame;
        }
    }

    AXLOGW("LegendAnimationFileInfo: private cache has {} frames for {}", _spriteFrames.size(), _name);
}

void LegendAnimationFileInfo::readFrames(LegendAnimationFileInfo* info, unsigned char* data, unsigned long dataSize)
{
    s_pdataEnd = data + dataSize;
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
                if (data + 3 > s_pdataEnd) break;
                unsigned short idx;
                memcpy(&idx, data, sizeof(unsigned short));
                felem.index = idx;
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

                    // DIAG: 只打印第一个动作前3帧的第一个元素
                    if (i == 0 && j < 3 && k == 0) {
                        AXLOGW("DIAG readFrames: ani={} action={} frame={} idx={} factor={:.4f}",
                               info->_name, action.name, j, felem.index, factor);
                        AXLOGW("DIAG readFrames: final a={:.4f} b={:.4f} c={:.4f} d={:.4f} tx={:.2f} ty={:.2f} w={:.0f} h={:.0f}",
                               dstA, -dstB, -dstC, dstD, dstTX, dstTY, fwidth, fheight);
                    }
                }
            }
        }
    }

    if (s_pdataEnd != data)
    {
        AXLOGW("LegendAnimationFileInfo: readFrames size mismatch for {}, remaining {} bytes",
               info->_name, (int)(s_pdataEnd - data));
    }
}

} // namespace ax
