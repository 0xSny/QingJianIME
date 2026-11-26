#include "../Keyboard/Core.hpp"
#include <cassert>
#include <filesystem>
#include <iostream>

int main(){
    namespace fs=std::filesystem;
    auto path=(fs::temp_directory_path()/("qj-test-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()))).string();
    const char* lex="Keyboard/Resources/lex.bin";
    {
        qj::Engine e(lex,path);
        auto check=[&](std::string input,bool fly,std::string word,bool first=false){
            auto h=e.decode(input,{},fly,0,0,"",0);
            if(first){assert(!h.empty());assert(h.front().text==word);}
            else assert(std::any_of(h.begin(),h.end(),[&](auto& v){return v.text==word && v.used==input.size();}));
        };
        check("nihao",false,"你好",true);
        check("nihc",true,"你好",true);
        check("zhong'guo",false,"中国",true);
        check("bjdx",false,"北京大学",true);
        check("wojintianxiangqubeijing",false,"我今天想去北京",true);
        check("aa",true,"啊");check("ee",true,"饿");check("oo",true,"哦");
        check("ai",true,"爱");check("an",true,"安");check("en",true,"恩");check("ah",true,"昂");
        check("eg",true,"嗯");
        e.learn("青柚舟","qing you zhou","",true);
        check("qingyouzhou",false,"青柚舟",true);
        check("qkyzvz",true,"青柚舟",true);
        check("qyz",false,"青柚舟",true);
        e.rollback();assert(e.count()==0);
        e.learn("青柚舟","qing you zhou","",true);e.flush();
        ++e.generation;assert(e.decode("nihao",{},false,0,1,"",0).empty());
    }
    {qj::Engine restored(lex,path);assert(restored.count()==1);restored.clear();restored.flush();}
    {qj::Engine restored(lex,path);assert(restored.count()==0);}
    fs::remove(path+".log");fs::remove(path+".snapshot");
    std::cout<<"Full spelling, Flypy, sentence ranking and learning checks passed.\n";
}
