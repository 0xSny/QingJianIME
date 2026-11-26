#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface QHit : NSObject
@property(nonatomic,copy) NSString *text;
@property(nonatomic,copy) NSString *reading;
@property(nonatomic) NSUInteger used;
@end
@interface QDecoder : NSObject
-(instancetype)initWithLex:(NSString *)lex storage:(NSString *)path;
-(uint64_t)invalidate;
-(NSArray<QHit *>*)search:(NSData*)input touches:(NSData*)touches fly:(BOOL)fly fuzzy:(int)mask spatial:(double)space previous:(NSString*)prev token:(uint64_t)token;
-(void)learn:(NSString*)word reading:(NSString*)reading previous:(NSString*)prev first:(BOOL)first;
-(void)erase:(NSString*)word reading:(NSString*)reading;
-(void)rollback;
-(void)flush;
-(void)clear;
-(NSUInteger)count;
@end
NS_ASSUME_NONNULL_END
