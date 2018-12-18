/****************************************************************************
 * Copyright 2016,2018, Optimizely, Inc. and contributors                   *
 *                                                                          *
 * Licensed under the Apache License, Version 2.0 (the "License");          *
 * you may not use this file except in compliance with the License.         *
 * You may obtain a copy of the License at                                  *
 *                                                                          *
 *    http://www.apache.org/licenses/LICENSE-2.0                            *
 *                                                                          *
 * Unless required by applicable law or agreed to in writing, software      *
 * distributed under the License is distributed on an "AS IS" BASIS,        *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
 * See the License for the specific language governing permissions and      *
 * limitations under the License.                                           *
 ***************************************************************************/

#import "OPTLYBaseCondition.h"
#import "OPTLYDatafileKeys.h"
#import "OPTLYNSObject+Validation.h"
#import "OPTLYLoggerMessages.h"
#import "OPTLYLogger.h"

@implementation OPTLYBaseCondition

/**
 * Given a json, this mapper finds JSON keys for each key in the provided dictionary and maps the json value to the class property with name corresponding to the dictionary value
 */
+ (OPTLYJSONKeyMapper*)keyMapper
{
    return [[OPTLYJSONKeyMapper alloc] initWithDictionary:@{ OPTLYDatafileKeysConditionName   : @"name",
                                                             OPTLYDatafileKeysConditionType  : @"type",
                                                             OPTLYDatafileKeysConditionValue  : @"value",
                                                             OPTLYDatafileKeysConditionMatch : @"match"
                                                             }];
}

+ (BOOL) isBaseConditionJSON:(NSData *)jsonData {
    if (![jsonData isKindOfClass:[NSDictionary class]]) {
        return false;
    }
    else {
        NSDictionary *dict = (NSDictionary *)jsonData;
        
        if (dict[OPTLYDatafileKeysConditionName] != nil &&
            dict[OPTLYDatafileKeysConditionType] != nil) {
            return true;
        }
        return false;
    }
}

-(nullable NSNumber *)evaluateMatchTypeExact:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config{
    // check if user attributes contain a value that is of similar class type to our value and also equals to our value, else return Null
    NSObject *userAttribute = [attributes objectForKey:self.name];
    NSNumber *success = NULL;
    
    if ([self.value isKindOfClass:[NSString class]] && [userAttribute isKindOfClass:[NSString class]]) {
        success = [NSNumber numberWithBool:[self.value isEqual:userAttribute]];
    }
    else if ([self.value isNumeric] && [userAttribute isNumeric]) {
        success = [NSNumber numberWithBool:[self.value isEqual:userAttribute]];
    }
    else if ([self.value isKindOfClass:[NSNull class]] && [userAttribute isKindOfClass:[NSNull class]]) {
        success = [NSNumber numberWithBool:[self.value isEqual:userAttribute]];
    }
    else if ([self.value isBool] && [userAttribute isBool]) {
        success = [NSNumber numberWithBool:[self.value isEqual:userAttribute]];
    }
    else {
        if (userAttribute) {
            NSString *logMessage = [NSString stringWithFormat:OPTLYLoggerMessagesAudienceEvaluatorConditionEvaluatedAsUnknownForInvalidValue, [self toJSONString], self.name, userAttribute ? userAttribute : @"nil"];
            [config.logger logMessage:logMessage withLevel:OptimizelyLogLevelWarning];
        }
        else {
            NSString *logMessage = [NSString stringWithFormat:OPTLYLoggerMessagesAudienceEvaluatorConditionEvaluatedAsUnknownForMissingAttribute, [self toJSONString], self.name];
            [config.logger logMessage:logMessage withLevel:OptimizelyLogLevelWarning];
        }
        
    }
    return success;
}

-(nullable NSNumber *)evaluateMatchTypeExist:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config{
    // check if user attributes contain our name as a key to a Non nullable object
    return [NSNumber numberWithBool:([attributes objectForKey:self.name] && ![attributes[self.name] isKindOfClass:[NSNull class]])];
}

-(nullable NSNumber *)evaluateMatchTypeSubstring:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config{
    // check if user attributes contain our value as substring
    NSObject *userAttribute = [attributes objectForKey:self.name];
    BOOL userAndOurValueHaveStringClassTypes = ([self.value isKindOfClass: [NSString class]] && [userAttribute isKindOfClass: [NSString class]]);
    
    if (userAndOurValueHaveStringClassTypes) {
        BOOL containsSubstring = [((NSString *)userAttribute) containsString: (NSString *)self.value];
        return [NSNumber numberWithBool:containsSubstring];
    }
    return NULL;
}

-(nullable NSNumber *)evaluateMatchTypeGreaterThan:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config{
    // check if user attributes contain a value greater than our value
    NSObject *userAttribute = [attributes objectForKey:self.name];
    BOOL userValueAndOurValueHaveNSNumberClassTypes = [self.value isNumeric] && [userAttribute isNumeric];
    
    if (userValueAndOurValueHaveNSNumberClassTypes) {
        NSNumber *ourValue = (NSNumber *)self.value;
        NSNumber *userValue = (NSNumber *)userAttribute;
        return [NSNumber numberWithBool: ([userValue doubleValue] > [ourValue doubleValue])];
    }
    return NULL;
}

-(nullable NSNumber *)evaluateMatchTypeLessThan:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config{
    // check if user attributes contain a value lesser than our value
    NSObject *userAttribute = [attributes objectForKey:self.name];
    BOOL userValueAndOurValueHaveNSNumberClassTypes = [self.value isNumeric] && [userAttribute isNumeric];
    
    if (userValueAndOurValueHaveNSNumberClassTypes) {
        NSNumber *ourValue = (NSNumber *)self.value;
        NSNumber *userValue = (NSNumber *)userAttribute;
        return [NSNumber numberWithBool: ([userValue doubleValue] < [ourValue doubleValue])];
    }
    return NULL;
}

-(nullable NSNumber *)evaluateCustomMatchType:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config {
    
    if (![self.type isEqual:OPTLYDatafileKeysCustomAttributeConditionType]){
        //Check if given type is the required type
        NSString *logMessage = [NSString stringWithFormat:OPTLYLoggerMessagesAudienceEvaluatorUnknownConditionType, [self toJSONString]];
        [config.logger logMessage:logMessage withLevel:OptimizelyLogLevelWarning];
        return NULL;
    }
    else if (!self.match || [self.match isEqualToString:@""]){
        //Check if given match is empty, if so, opt for legacy Exact Matching
        self.match = OPTLYDatafileKeysMatchTypeExact;
    }
    else if (self.value == NULL && ![self.match isEqualToString:OPTLYDatafileKeysMatchTypeExists]){
        //Check if given value is null, which is only acceptable if match type is Exists
        NSString *logMessage = [NSString stringWithFormat:OPTLYLoggerMessagesAudienceEvaluatorUnknownConditionValue, [self toJSONString]];
        [config.logger logMessage:logMessage withLevel:OptimizelyLogLevelWarning];
        return NULL;
    }
    
    SWITCH(self.match){
        CASE(OPTLYDatafileKeysMatchTypeExact) {
            return [self evaluateMatchTypeExact: attributes projectConfig:config];
        }
        CASE(OPTLYDatafileKeysMatchTypeExists) {
            return [self evaluateMatchTypeExist: attributes projectConfig:config];
        }
        CASE(OPTLYDatafileKeysMatchTypeSubstring) {
            return [self evaluateMatchTypeSubstring: attributes projectConfig:config];
        }
        CASE(OPTLYDatafileKeysMatchTypeGreaterThan) {
            return [self evaluateMatchTypeGreaterThan: attributes projectConfig:config];
        }
        CASE(OPTLYDatafileKeysMatchTypeLessThan) {
            return [self evaluateMatchTypeLessThan: attributes projectConfig:config];
        }
        DEFAULT {
            NSString *logMessage = [NSString stringWithFormat:OPTLYLoggerMessagesAudienceEvaluatorUnknownMatchType, [self toJSONString]];
            [config.logger logMessage:logMessage withLevel:OptimizelyLogLevelWarning];
            return NULL;
        }
    }
}

/**
 * Evaluates the condition against the user attributes, returns NULL if invalid.
 */
- (nullable NSNumber *)evaluateConditionsWithAttributes:(NSDictionary<NSString *, NSObject *> *)attributes projectConfig:(nullable OPTLYProjectConfig *)config {
    // check user attribute value for the condition and match type against our condition value
    return [self evaluateCustomMatchType: attributes projectConfig:config];
}

@end

