#include "../Keyboard/Core.hpp"
#include <cassert>
int main(){
    qj::Engine engine("Keyboard/Resources/lex.bin","/tmp/qj-unit");
    auto check=[&](std::string input,bool fly,std::string word){
        auto h=engine.decode(input,{},fly,0,0,"",0);
        assert(std::any_of(h.begin(),h.end(),[&](auto& v){return v.text==word && v.used==input.size();}));
    };
    check("nihao",false,"你好");check("nihc",true,"你好");check("zhong'guo",false,"中国");
    check("aa",true,"啊");
}
