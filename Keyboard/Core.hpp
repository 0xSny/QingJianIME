#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <map>
#include <queue>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <io.h>
#else
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#endif
#include <vector>

namespace qj {
using std::string;
struct Header { char magic[4]; uint32_t version,crc,bytes[6],length; };
struct Edge { uint32_t sound,node; };
struct Node { uint32_t edge,count,word,words; };
struct Word { uint32_t text,reading; float frequency; };
struct Sound { uint32_t full,fly; };
struct Pair { uint32_t left,right,count; };
struct Tap { char keys[3]; float costs[3]; };
struct Hit { string text,reading; unsigned used; double score; int tier; };
struct Memory { double count,time; };
inline double now() { return std::chrono::duration<double>(std::chrono::system_clock::now().time_since_epoch()).count(); }
inline double decayed(Memory m) { return m.count * std::exp2(-std::max(0.,now()-m.time)/2592000.); }
class Engine {
    const void *mapping=nullptr; size_t size=0;
    const Sound *sounds=nullptr; const Node *nodes=nullptr; const Edge *edges=nullptr;
    const Word *words=nullptr; const Pair *pairs=nullptr; const char *pool=nullptr;
    unsigned ns=0,np=0;
    std::map<string,Memory> memory;
    std::map<string,Memory> pending,undo;
    string file;
    static string key(const string& word,const string& reading) { return reading+"\t"+word; }
    double weight(const string& k) const {
        auto it=memory.find(k); return it==memory.end()?0:std::log1p(decayed(it->second))*9;
    }
    void assign(const string& k, Memory m) {
        pending[k]=m;
        if(m.count>0.001) memory[k]=m; else memory.erase(k);
    }
    double transition(std::string_view a,unsigned b) const {
        auto p=std::lower_bound(pairs,pairs+np,std::make_pair(a,b),[this](Pair p,auto k){
            return std::make_pair(std::string_view(pool+p.left),p.right)<k;
        });
        return p!=pairs+np && std::string_view(pool+p->left)==a && p->right==b ? std::log1p(p->count):0.;
    }
public:
    std::atomic<uint64_t> generation{0};
    Engine(const char* lex,string path):file(std::move(path)) {
        #ifdef _WIN32
        HANDLE fd=CreateFileA(lex,GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
        if(fd==INVALID_HANDLE_VALUE)return;
        LARGE_INTEGER length;
        if(GetFileSizeEx(fd,&length) && length.QuadPart>=sizeof(Header)){
            size=length.QuadPart;
            HANDLE section=CreateFileMappingA(fd,nullptr,PAGE_READONLY,0,0,nullptr);
            if(section){mapping=MapViewOfFile(section,FILE_MAP_READ,0,0,0); CloseHandle(section);}
        }
        CloseHandle(fd);if(!mapping)return;
#else
        int fd=open(lex,O_RDONLY); if(fd<0)return;
        struct stat st{}; if(fstat(fd,&st)==0 && st.st_size>=sizeof(Header)){
            size=st.st_size; mapping=mmap(nullptr,size,PROT_READ,MAP_PRIVATE,fd,0);
        }
        close(fd); if(mapping==MAP_FAILED){mapping=nullptr;return;} if(!mapping)return;
#endif
        const auto& h=*static_cast<const Header*>(mapping);
        uint64_t total=sizeof(Header); for(auto n:h.bytes)total+=n;
        if(memcmp(h.magic,"QJ17",4)||h.version!=1||total!=size||h.bytes[1]<sizeof(Node))return;
        auto p=static_cast<const char*>(mapping)+sizeof(Header);
        sounds=reinterpret_cast<const Sound*>(p); ns=h.bytes[0]/sizeof(Sound); p+=h.bytes[0];
        nodes=reinterpret_cast<const Node*>(p);p+=h.bytes[1];
        edges=reinterpret_cast<const Edge*>(p);p+=h.bytes[2];
        words=reinterpret_cast<const Word*>(p);p+=h.bytes[3];
        pairs=reinterpret_cast<const Pair*>(p);np=h.bytes[4]/sizeof(Pair);p+=h.bytes[4];pool=p;
        for(const auto& suffix:{".snapshot",".log"}){
            std::ifstream in(file+suffix); string line;
            while(std::getline(in,line)){
                std::istringstream row(line); Memory m{}; string k;
                if(row>>m.count>>m.time && row.get()=='\t' && std::getline(row,k)){
                    if(m.count>0)memory[k]=m;else memory.erase(k);
                }
            }
        }
    }
    ~Engine(){
#ifdef _WIN32
        if(mapping)UnmapViewOfFile(mapping);
#else
        if(mapping)munmap(const_cast<void*>(mapping),size);
#endif
    }
    void flush(){
        if(pending.empty())return;
        auto write=[](auto& out,const auto& data){
            out.precision(17);
            for(const auto& [k,m]:data)out<<m.count<<'\t'<<m.time<<'\t'<<k<<'\n';
        };
        std::ofstream out(file+".log",std::ios::app);write(out,pending);out.flush();
        if(!out)return;pending.clear(); if(out.tellp()<131072)return;out.close();
        std::ofstream snap(file+".tmp");write(snap,memory);snap.close();
        if(snap && rename((file+".tmp").c_str(),(file+".snapshot").c_str())==0)std::remove((file+".log").c_str());
    }
    void learn(string word,string reading,string prev,bool first){
        if(first)undo.clear();
        if(reading.empty()||word.empty())return;
        for(auto k:{key(word,reading),"@"+prev+"\t"+word}){
            if(k[0]=='@' && prev.empty())continue;
            auto old=memory.count(k)?memory.at(k):Memory{};
            undo.emplace(k,old);assign(k,{decayed(old)+1,now()});
        }
    }
    void rollback(){for(auto& [k,v]:undo)assign(k,v);undo.clear();}
    void erase(string word,string reading){assign(key(word,reading),{});undo.clear();}
    void clear(){auto copy=memory;for(auto& [k,v]:copy)assign(k,{});undo.clear();}
    uint32_t continuations(const string& raw,bool fly)const {
        if(!pool || raw.empty())return 0;
        uint32_t mask=0;
        for(unsigned sid=0;sid<ns;sid++){
            std::string_view code(pool+(fly?sounds[sid].fly:sounds[sid].full));
            for(size_t k=1;k<code.size() && k<=raw.size();k++)
                if(raw.compare(raw.size()-k,k,code.data(),k)==0) mask|=1u<<(code[k]-'a');
        }
        return mask;
    }
    size_t count()const{return std::count_if(memory.begin(),memory.end(),[](auto& x){return x.first[0]!='@';});}
    std::vector<Hit> decode(const string& raw,const std::vector<Tap>& taps,bool fly,int fuzzy,double spatial,string previous,uint64_t token){
        if(!pool || raw.empty() || raw.size()>256)return {};
        const unsigned n=raw.size();
        struct Match { unsigned sid,end; double penalty; };
        std::vector<std::vector<Match>> lattice(n);
        static const std::pair<string,string> groups[]={{"zh","z"},{"ch","c"},{"sh","s"},{"n","l"},{"f","h"},{"l","r"},{"an","ang"},{"en","eng"},{"in","ing"},{"ian","iang"},{"uan","uang"}};
        for(unsigned i=0;i<n;i++){
            if(generation!=token)return {};
            for(unsigned s=0;s<ns;s++){
                string code=pool+(fly?sounds[s].fly:sounds[s].full);
                auto add=[&](string k,double base){
                    if(k.empty()||i+k.size()>n)return;
                    double cost=base;
                    for(unsigned j=0;j<k.size();j++){
                        if(raw[i+j]==k[j])continue;
                        if(spatial<=0||i+j>=taps.size())return;
                        auto& tap=taps[i+j];int t=0;while(t<3 && tap.keys[t]!=k[j])t++;
                        if(t==3)return;cost+=4+tap.costs[t]/spatial;
                    }
                    unsigned end=i+k.size(); if(end<n && raw[end]=='\'')end++;
                    lattice[i].push_back({s,end,cost});
                };
                add(code,0);
                if(code.size()>1)add(code.substr(0,1),5);
                if(!fly && !code.empty() && code.size()>n-i && n-i>1 && code.compare(0,n-i,raw,i,n-i)==0)
                    add(code.substr(0,n-i),6.5);
                if(!fly && code.size()>2 && code[1]=='h')add(code.substr(0,2),4.7);
                if(!fly){
                    if(code.size()>=3 && spatial>0){
                        for(size_t j=1;j<code.size();j++){ auto alt=code;std::swap(alt[j-1],alt[j]);if(alt!=code)add(alt,5); }
                    }
                    for(unsigned g=0;g<11;g++)if(fuzzy&(1<<g)){
                        for(int rev=0;rev<2;rev++){
                            auto from=rev?groups[g].second:groups[g].first;
                            auto to=rev?groups[g].first:groups[g].second;
                            if(code.size()<from.size())continue;
                            size_t at=g<6?0:code.size()-from.size();
                            if(code.compare(at,from.size(),from)==0)add(string(code).replace(at,from.size(),to),3.5);
                        }
                    }
                }
            }
            auto& m=lattice[i];std::sort(m.begin(),m.end(),[](auto a,auto b){return a.penalty<b.penalty;});
        }
        struct Path{string text,reading;double score=0,penalty=0;unsigned last=0;};
        std::vector<std::vector<Path>> best(n+1);best[0].push_back({});
        std::vector<Hit> hits;
        for(unsigned start=0;start<n;start++){
            if(generation!=token)return {};
            auto& paths=best[start];if(paths.empty())continue;
            auto prune=[](auto& a){std::sort(a.begin(),a.end(),[](auto& x,auto& y){if((x.penalty==0)!=(y.penalty==0))return x.penalty==0;return x.score>y.score;});if(a.size()>4)a.resize(4);};
            prune(paths);
            struct Cursor{unsigned node,pos;double cost;};
            std::vector<Cursor> frontier{{0,start,0}};
            while(!frontier.empty()){
                std::vector<Cursor> next;
                for(auto c:frontier){
                    if(generation!=token)return {};
                    const auto& nd=nodes[c.node];
                    for(auto m:lattice[c.pos]){
                        auto edge=std::lower_bound(edges+nd.edge,edges+nd.edge+nd.count,m.sid,[](Edge e,unsigned s){return e.sound<s;});
                        if(edge==edges+nd.edge+nd.count||edge->sound!=m.sid)continue;
                        auto& dest=nodes[edge->node];double cost=c.cost+m.penalty;
                        if(m.end<n && dest.count)next.push_back({edge->node,m.end,cost});
                        for(unsigned w=0;w<std::min(dest.words,12u);w++){
                            auto item=words[dest.word+w];string word=pool+item.text,read=pool+item.reading;
                            double base=item.frequency*.50-12-cost+weight(key(word,read));
                            if(!start)hits.push_back({word,read,m.end,base+weight("@"+previous+"\t"+word),m.end==n?(cost==0?1:2):3});
                            if(w>2)continue;
                            for(auto& path:paths){
                                double sc=path.score+base-(start && cost>0 ? 2.0:0.0)+transition(start?std::string_view(pool+path.last):std::string_view(previous),item.text)+weight("@"+(start?string(pool+path.last):previous)+"\t"+word);
                                auto& destPaths=best[m.end];
                                destPaths.push_back({path.text+word,path.reading+(start?" ":"")+read,sc,path.penalty+cost,item.text});
                                if(destPaths.size()>16)prune(destPaths);
                            }
                        }
                    }
                }
                std::sort(next.begin(),next.end(),[](auto a,auto b){return a.cost<b.cost;});
                if(next.size()>24)next.resize(24);frontier.swap(next);
            }
        }
        auto& complete=best[n];
        std::sort(complete.begin(),complete.end(),[](const Path& a,const Path& b){
            if((a.penalty==0)!=(b.penalty==0))return a.penalty==0;return a.score>b.score;
        });
        for(size_t i=0;i<complete.size();++i){auto& p=complete[i];hits.push_back({p.text,p.reading,n,p.score,i==0 && p.penalty==0?0:2});}
        for(auto& [k,mem]:memory){
            if(generation!=token)return {};
            if(k.front()=='@')continue;
            auto tab=k.find('\t');if(tab==string::npos)continue;
            auto reading=k.substr(0,tab);std::istringstream seq(reading);string s;
            std::set<unsigned> ends{0};
            while(seq>>s && !ends.empty()){
                std::set<unsigned> next;
                for(auto i:ends)if(i<n)for(auto m:lattice[i])if(m.penalty<=5 && s==pool+sounds[m.sid].full)next.insert(m.end);
                ends.swap(next);
            }
            if(ends.count(n))hits.push_back({k.substr(tab+1),reading,n,weight(k)+3,0});
        }
        std::sort(hits.begin(),hits.end(),[](const Hit& a,const Hit& b){
            if(a.tier!=b.tier)return a.tier<b.tier;
            if(a.used!=b.used)return a.used>b.used;return a.score>b.score;
        });
        std::vector<Hit> result;std::set<string> seen;
        for(auto& h:hits)if(seen.insert(h.text).second){result.push_back(h);if(result.size()==80)break;}
        return result;
    }
};
}
