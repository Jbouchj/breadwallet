//
//  ZNElecturmMnemonic.m
//  ZincWallet
//
//  Created by Aaron Voisine on 7/19/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "ZNElecturmMnemonic.h"
#import "NSString+Base58.h"

#define WORDS @"ElectrumSeedWords"

@implementation ZNElecturmMnemonic

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{ singleton = [self new]; });
    return singleton;
}

//# Note about US patent no 5892470: Here each word does not represent a given digit.
//# Instead, the digit represented by a word is variable, it depends on the previous word.
//
//def mn_encode( message ):
//    out = []
//    for i in range(len(message)/8):
//        word = message[8*i:8*i + 8]
//        x = int(word, 16)
//        w1 = (x % n)
//        w2 = ((x/n) + w1) % n
//        w3 = ((x/n/n) + w2) % n
//        out += [ words[w1], words[w2], words[w3] ]
//    return out
//
- (NSString *)encodePhrase:(NSData *)data
{
    NSArray *words = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:WORDS ofType:@"plist"]];
    uint32_t n = words.count, x, w1, w2, w3;
    NSMutableArray *a =
        CFBridgingRelease(CFArrayCreateMutable(SecureAllocator(), data.length*3/4, &kCFTypeArrayCallBacks));

    for (int i = 0; i*sizeof(uint32_t) < data.length; i++) {
        x = CFSwapInt32BigToHost(*((uint32_t *)data.bytes + i));
        w1 = x % n;
        w2 = ((x/n) + w1) % n;
        w3 = ((x/n/n) + w2) % n;

        [a addObject:words[w1]];
        [a addObject:words[w2]];
        [a addObject:words[w3]];
    }

    x = w1 = w2 = w3 = 0;
    return CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (__bridge CFArrayRef)a, CFSTR(" ")));
}

//def mn_decode( wlist ):
//    out = ''
//    for i in range(len(wlist)/3):
//        word1, word2, word3 = wlist[3*i:3*i + 3]
//        w1 =  words.index(word1)
//        w2 = (words.index(word2)) % n
//        w3 = (words.index(word3)) % n
//        x = w1 + n*((w2 - w1) % n) + n*n*((w3 - w2) % n)
//        out += '%08x'%x
//    return out
//
- (NSData *)decodePhrase:(NSString *)phrase
{
    NSArray *words = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:WORDS ofType:@"plist"]];
    CFMutableStringRef s = CFStringCreateMutableCopy(SecureAllocator(), phrase.length, (__bridge CFStringRef)phrase);

    CFStringTrimWhitespace(s);

    NSArray *a = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(), s, CFSTR(" ")));
    NSMutableData *d = CFBridgingRelease(CFDataCreateMutable(SecureAllocator(), a.count*4/3));
    int32_t n = words.count, x, w1, w2, w3;

    if (a.count != 12) {
        NSLog(@"phrase should be 12 words, found %d instead", a.count);
        return nil;
    }

    for (NSUInteger i = 0; i < a.count; i += 3) {
        w1 = [words indexOfObject:a[i]];
        w2 = [words indexOfObject:a[i + 1]];
        w3 = [words indexOfObject:a[i + 2]];

        if (w1 == NSNotFound || w2 == NSNotFound || w3 == NSNotFound) {
            NSLog(@"phrase contained unknown word: %@", a[i + (w1 == NSNotFound ? 0 : w2 == NSNotFound ? 1 : 2)]);
            return nil;
        }

        // python's modulo behaves differently than C's when dealing with negative numbers
        // the equivalent of python's (n % M) in C is (((n % M) + M) % M)
        x = CFSwapInt32HostToBig(w1 + n*((((w2 - w1) % n) + n) % n) + n*n*((((w3 - w2) % n) + n) % n));
        
        [d appendBytes:&x length:sizeof(x)];
    }
    
    x = w1 = w2 = w3 = 0;
    return d;
}


@end
