//
//  IDLObject.m
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/17/20.
//

#import "IDLObject.h"

@implementation IDLObject

- (instancetype)init
{
    if (self = [super init]) {
        [self iniialize];
    }

    return self;
}

- (void)iniialize
{
    NSLog(@"Override in subclasses");
}

@end
