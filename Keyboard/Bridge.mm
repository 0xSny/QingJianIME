#import "Bridge.h"
#include "Core.hpp"
#include <memory>
@implementation QHit
@end
@implementation QDecoder { std::unique_ptr<qj::Engine> _engine; }
-(instancetype)initWithLex:(NSString*)lex storage:(NSString*)path {
    if((self=[super init]))_engine=std::make_unique<qj::Engine>(lex.fileSystemRepresentation,path.fileSystemRepresentation);
    return self;
}
-(uint64_t)invalidate { return ++_engine->generation; }
-(NSArray<QHit*>*)search:(NSData*)input touches:(NSData*)touches fly:(BOOL)fly fuzzy:(int)mask spatial:(double)space previous:(NSString*)prev token:(uint64_t)token {
    std::vector<qj::Tap> taps(touches.length/6);
    auto b=static_cast<const unsigned char*>(touches.bytes);
    for(size_t i=0;i<taps.size();i++)for(int j=0;j<3;j++){
        taps[i].keys[j]=b[i*6+j]; taps[i].costs[j]=b[i*6+3+j]/12.;
    }
    auto result=[NSMutableArray array];
    if(!input.length)return result;
    for(auto& h:_engine->decode(std::string((const char*)input.bytes,input.length),taps,fly,mask,space,prev.UTF8String,token)){
        QHit *v=[QHit new];v.text=[NSString stringWithUTF8String:h.text.c_str()];v.reading=[NSString stringWithUTF8String:h.reading.c_str()];v.used=h.used;[result addObject:v];
    }
    return result;
}
-(void)learn:(NSString*)word reading:(NSString*)r previous:(NSString*)p first:(BOOL)first { _engine->learn(word.UTF8String,r.UTF8String,p.UTF8String,first); }
-(void)erase:(NSString*)word reading:(NSString*)r { _engine->erase(word.UTF8String,r.UTF8String); }
-(void)rollback { _engine->rollback(); }
-(void)flush { _engine->flush(); }
-(void)clear { _engine->clear(); }
-(NSUInteger)count { return _engine->count(); }
@end
