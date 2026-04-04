#pragma once

#include "axmol/axmol.h"
#include <string>
#include <unordered_map>
#include <functional>

namespace ccb {

class CCNodeLoader;

// 注册表：类名 -> 加载器创建函数
class CCNodeLoaderLibrary : public ax::Object
{
public:
    static CCNodeLoaderLibrary* create();
    virtual ~CCNodeLoaderLibrary();

    void registerDefaultCCNodeLoaders();
    void registerCCNodeLoader(const std::string& className, CCNodeLoader* loader);
    void unregisterCCNodeLoader(const std::string& className);
    CCNodeLoader* getCCNodeLoader(const std::string& className);

private:
    std::unordered_map<std::string, CCNodeLoader*> mLoaders;
};

} // namespace ccb
