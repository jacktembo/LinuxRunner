// LinuxRunner design tokens for UIKit/Objective-C views. Same values as
// DesignSystem.swift (DS.Palette); keep the two in step.
#ifndef LR_DESIGN_H
#define LR_DESIGN_H
#import <UIKit/UIKit.h>

static inline UIColor *LRHex(uint32_t hex) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1];
}
static inline UIColor *LRDynamic(uint32_t dark, uint32_t light) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleLight ? LRHex(light) : LRHex(dark);
    }];
}

// Adaptive (follow Appearance).
static inline UIColor *LRAccent(void) { return LRDynamic(0xFF7A1A, 0xC2410C); }
static inline UIColor *LRDanger(void) { return LRDynamic(0xFF5A52, 0xC8251B); }
static inline UIColor *LRSuccess(void) { return LRDynamic(0x34C759, 0x1A8F3C); }

// Terminal chrome: always dark, next to the true-black terminal.
static inline UIColor *LRTerminalBackground(void) { return UIColor.blackColor; }
static inline UIColor *LRTerminalKey(void) { return LRHex(0x1C1C1E); }
static inline UIColor *LRTerminalKeyPressed(void) { return LRHex(0x2A2A2F); }
static inline UIColor *LRTerminalBorder(void) { return LRHex(0x2C2C31); }
static inline UIColor *LRTerminalText(void) { return LRHex(0xF4F4F5); }
static inline UIColor *LRTerminalAccent(void) { return LRHex(0xFF7A1A); }

#endif
