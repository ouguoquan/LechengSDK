//
//  RestApiService.m
//  appDemo
//
//  Created by chenjian on 15/5/25.
//  Copyright (c) 2015年 yao_bao. All rights reserved.
//

#import "RestApiService.h"
#import "BeAuthDeviceList.h"
#import "BindDevice.h"
#import "BindDeviceInfo.h"
#import "CheckDeviceBindOrNot.h"
#import "UnBindDeviceInfo.h"
#import "ControlPTZ.h"
#import "DeleteAlarmMessage.h"
#import "DeviceList.h"
#import "DeviceOnline.h"
#import "GetAlarmMessage.h"
#import "ModifyDeviceAlarmStatus.h"
#import "QueryCloudRecordNum.h"
#import "QueryCloudRecords.h"
#import "QueryLocalRecordNum.h"
#import "QueryLocalRecords.h"
#import "SetAllStorageStrategy.h"
#import "SetStorageStrategy.h"
#import "ShareDeviceList.h"
#import "UnBindDevice.h"
#import "GetStorageStrategy.h"
#import "ModifyDevicePwd.h"
#import "UpgradeDevice.h"
#import "UpgradeProcessDevice.h"
#import "LCOpenSDK_LoginManager.h"
#import "BreathingLightStatus.h"
#import "FrameReverseStatus.h"
#import "ModifyDeviceName.h"
#import "ModifyBreathingLight.h"
#import "ModifyFrameReverseStatus.h"
#import "RecoverSDCard.h"

#define ACCESSTOKEN_LEN 256

const NSString* NETWORK_TIMEOUT = @"网络超时";
const NSString* INTERFACE_FAILED = @"接口调用失败";
const NSString* MSG_SUCCESS = @"成功";
const NSString* MSG_DEVICE_ONLINE = @"设备在线";
const NSString* MSG_DEVICE_OFFLINE = @"设备离线";
const NSString* MSG_DEVICE_IS_BIND = @"设备已绑定";
const NSString* MSG_DEVICE_NOT_BIND = @"设备未绑定";

using namespace Dahua::LCOpenApi;

@interface RestApiService () {
    LCOpenSDK_Api* m_hc;
    char m_accessToken[ACCESSTOKEN_LEN];
}
@end

@implementation RestApiService

static RestApiService* _instance = nil;
+ (instancetype)shareMyInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] initPrivate];
    });
    return _instance;
}

- (instancetype)initPrivate
{
    self = [super init];
    return self;
}

- (NSString*)stringWithStdString:(string)str
{
    if (!str.c_str()) {
        return nil;
    }
    return [NSString stringWithUTF8String:str.c_str()];
}

- (NSString *)getToken
{
    return [NSString stringWithUTF8String:m_accessToken];
}

- (void)invalidToken
{
    if (m_accessToken) {
        strncpy(m_accessToken, "", sizeof(m_accessToken) - 1);
    }
}

- (void)initComponent:(LCOpenSDK_Api*)hc Token:(NSString*)accessTok_In
{
    if (nil != hc) {
        m_hc = hc;
    }
    if (nil != accessTok_In) {
        strncpy(m_accessToken, [accessTok_In UTF8String], sizeof(m_accessToken) - 1);
    }
}

- (BOOL)getDevList:(NSMutableArray*)info_Out Begin:(NSInteger)beginIndex_In End:(NSInteger)endIndex_In Msg:(NSString**)errMsg_Out
{
    NSString* sRange = [NSString stringWithFormat:@"%ld-%ld", (long)beginIndex_In, (long)endIndex_In];

    DeviceListRequest req;
    DeviceListResponse resp;
    req.data.token = m_accessToken;
    req.data.queryRange = [sRange UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int i = 0; i < resp.data.devices.size(); i++) {
                    DeviceInfo* deviceInfo = [[DeviceInfo alloc] init];
                    DeviceListResponseData_DevicesElement *device = resp.data.devices.at(i);
                    deviceInfo->ID = [self stringWithStdString:device->deviceId];
                    deviceInfo->platForm = device->platForm;
                    deviceInfo->ability = [self stringWithStdString:device->ability];
                    deviceInfo->devOnline = device->status;
                    deviceInfo->encryptMode = device->encryptMode;
                    deviceInfo->channelSize = device->channels.size();
                    for (int channelIndex = 0; channelIndex < resp.data.devices.at(i)->channels.size() && channelIndex < CHANNEL_MAX; channelIndex++) {
                        DeviceListResponseData_DevicesElement_ChannelsElement *channel = device->channels.at(channelIndex);
                        deviceInfo->channelId[channelIndex] = channel->channelId;
                        deviceInfo->isOnline[channelIndex] = channel->channelOnline;
                        deviceInfo->csStatus[channelIndex] = (CloudStorageStatus)channel->csStatus;
                        deviceInfo->channelPic[channelIndex] = [self stringWithStdString:channel->channelPicUrl];
                        deviceInfo->channelName[channelIndex] = [self stringWithStdString:channel->channelName];
                        deviceInfo->channelAbility[channelIndex] = [self stringWithStdString:channel->channelAbility];
                    }
                    [info_Out addObject:deviceInfo];
//                    [[LCOpenSDK_LoginManager shareMyInstance] addDevices:[NSString stringWithUTF8String:m_accessToken] devicesJsonStr:[NSString stringWithFormat:@"%s%@%s", "[{\"Sn\":\"", deviceInfo->ID, "\", \"Type\":1,\"Port\":554,\"User\":\"\", \"Pwd\":\"\"}]"] failure:^(NSString *err) {
//                        NSLog(@"p2p addDevices failed[%@]", err);
//                    }];
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)beAuthDeviceList:(NSMutableArray*)info_Out Begin:(NSInteger)beginIndex_In End:(NSInteger)endIndex_In Msg:(NSString**)errMsg_Out
{
    NSString* sRange = [NSString stringWithFormat:@"%ld-%ld", (long)beginIndex_In, (long)endIndex_In];
    
    BeAuthDeviceListRequest req;
    BeAuthDeviceListResponse resp;
    req.data.token = m_accessToken;
    req.data.queryRange = [sRange UTF8String];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int i = 0; i < resp.data.devices.size(); i++) {
                    DeviceInfo* deviceInfo = [[DeviceInfo alloc] init];
                    BeAuthDeviceListResponseData_DevicesElement *device = resp.data.devices.at(i);
                    
                    deviceInfo->ID = [self stringWithStdString:device->deviceId];
                    deviceInfo->ability = [self stringWithStdString:device->ability];
                    deviceInfo->devOnline = device->status;
                    deviceInfo->channelSize = 1;
                    deviceInfo->encryptMode = device->encryptMode;
                    deviceInfo->channelId[0] = device->channelId;
                    deviceInfo->isOnline[0] = device->channelOnline;
                    deviceInfo->csStatus[0] = (CloudStorageStatus)device->csStatus;
                    deviceInfo->channelPic[0] = [self stringWithStdString:device->channelPicUrl];
                    deviceInfo->channelName[0] = [self stringWithStdString:device->channelName];
                    [info_Out addObject:deviceInfo];
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)shareDeviceList:(NSMutableArray*)info_Out Begin:(NSInteger)beginIndex_In End:(NSInteger)endIndex_In Msg:(NSString**)errMsg_Out
{
    NSString* sRange = [NSString stringWithFormat:@"%ld-%ld", (long)beginIndex_In, (long)endIndex_In];
    
    ShareDeviceListRequest req;
    ShareDeviceListResponse resp;
    req.data.token = m_accessToken;
    req.data.queryRange = [sRange UTF8String];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    NSLog(@"getDevList ret[%ld]", (long)ret);
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int i = 0; i < resp.data.devices.size(); i++) {
                    DeviceInfo* deviceInfo = [[DeviceInfo alloc] init];
                    ShareDeviceListResponseData_DevicesElement *device = resp.data.devices.at(i);
                    
                    deviceInfo->ID = [self stringWithStdString:device->deviceId];
                    deviceInfo->ability = [self stringWithStdString:device->ability];
                    deviceInfo->devOnline = device->status;
                    deviceInfo->channelSize = device->channels.size();
                    deviceInfo->encryptMode = device->encryptMode;
                    for (int channelIndex = 0; channelIndex < resp.data.devices.at(i)->channels.size() && channelIndex < CHANNEL_MAX; channelIndex++) {
                        ShareDeviceListResponseData_DevicesElement_ChannelsElement *channel = device->channels.at(channelIndex);
                        
                        deviceInfo->channelId[channelIndex] = channel->channelId;
                        deviceInfo->isOnline[channelIndex] = channel->channelOnline;
                        deviceInfo->channelPic[channelIndex] = [self stringWithStdString:channel->channelPicUrl];
                        deviceInfo->channelName[channelIndex] = [self stringWithStdString:channel->channelName];
                    }
                    [info_Out addObject:deviceInfo];
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)checkDeviceOnline:(NSString*)devID_In Msg:(NSString**)errMsg_Out
{
    DeviceOnlineRequest req;
    DeviceOnlineResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                NSLog(@"checkDeviceOnline success");
                if (resp.data.onLine.c_str()) {
                    NSString *deviceOnle = [self stringWithStdString:resp.data.onLine];
                    *errMsg_Out = [@"1" isEqualToString:deviceOnle]
                    ? [MSG_DEVICE_ONLINE mutableCopy]
                    : [MSG_DEVICE_OFFLINE mutableCopy];
                }
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)checkDeviceBindOrNot:(NSString*)devID_In Msg:(NSString**)errMsg_Out
{
    CheckDeviceBindOrNotRequest req;
    CheckDeviceBindOrNotResponse resp;
    req.data.deviceId = [devID_In UTF8String];
    req.data.token = m_accessToken;
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                NSLog(@"checkDeviceBindOrNot bMine[%d],bIsBind[%d]",
                      resp.data.isMine, resp.data.isBind);
                *errMsg_Out = resp.data.isBind ? [MSG_DEVICE_IS_BIND mutableCopy] : [MSG_DEVICE_NOT_BIND mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)unBindDeviceInfo:(NSString*)devID_In Ability:(NSString**)ability Msg:(NSString**)errMsg_Out
{
    UnBindDeviceInfoRequest req;
    UnBindDeviceInfoResponse resp;
    req.data.deviceId = [devID_In UTF8String];
    req.data.token = m_accessToken;
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
                *ability = [self stringWithStdString:resp.data.ability];
                NSLog(@"unBindDeviceInfo ability[%@]", *ability);
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)bindDevice:(NSString*)devID_In Code:(NSString *)code Msg:(NSString**)errMsg_Out
{
    BindDeviceRequest req;
    BindDeviceResponse resp;
    req.data.deviceId = [devID_In UTF8String];
    req.data.token = m_accessToken;
    req.data.code = [code UTF8String];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                NSLog(@"bindDevice success");
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)unBindDevice:(NSString*)devID_In Msg:(NSString**)errMsg_Out
{
    UnBindDeviceRequest req;
    UnBindDeviceResponse resp;
    req.data.deviceId = [devID_In UTF8String];
    req.data.token = m_accessToken;
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                NSLog(@"unBindDevice success");
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getBindDeviceInfo:(NSString*)devID_In Info_out:(DeviceInfo*)info_out Msg:(NSString**)errMsg_Out
{
    BindDeviceInfoRequest req;
    BindDeviceInfoResponse resp;
    req.data.deviceId = [devID_In UTF8String];
    req.data.token = m_accessToken;
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int channelIndex = 0; channelIndex < resp.data.channels.size() && channelIndex < CHANNEL_MAX; channelIndex++) {
                    if (info_out) {
                        BindDeviceInfoResponseData_ChannelsElement *channel = resp.data.channels.at(channelIndex);
                        info_out->alarmStatus[channelIndex] = (AlarmStatus)channel->alarmStatus;
                        info_out->csStatus[channelIndex] = (CloudStorageStatus)channel->csStatus;
                    }
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getAlarmMsg:(NSString*)devID_In Chnl:(NSInteger)iCh_In Begin:(NSString*)beginTime_In End:(NSString*)endTime_In Info:(NSMutableArray*)msgInfo_Out Count:(NSInteger)count_In Msg:(NSString**)errMsg_Out
{
    char strCh[10] = { 0 };
    char strCount[10] = { 0 };
    snprintf(strCount, sizeof(strCount) - 1, "%ld", (long)count_In);
    snprintf(strCh, sizeof(strCh) - 1, "%ld", (long)iCh_In);
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    GetAlarmMessageRequest req;
    GetAlarmMessageResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = strCh;
    req.data.beginTime = [beginTime_In UTF8String];
    req.data.endTime = [endTime_In UTF8String];
    req.data.count = strCount;
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int i = 0; i < resp.data.alarms.size(); i++) {
                    AlarmMessageInfo *alarmInfo = [[AlarmMessageInfo alloc] init];
                    GetAlarmMessageResponseData_AlarmsElement *alarm = resp.data.alarms.at(i);
                    alarmInfo->deviceId = [self stringWithStdString:alarm->deviceId];
                    alarmInfo->channel = std::stoi(alarm->channelId);
                    alarmInfo->channelName = [self stringWithStdString:alarm->name];
                    alarmInfo->alarmId = alarm->alarmId;
                    alarmInfo->thumbnail = [self stringWithStdString:alarm->thumbUrl];
                    for (int j = 0; j < resp.data.alarms.at(i)->picurlArray.size() && j < PIC_ARRAY_MAX; j++)
                    {
                        alarmInfo->picArray[j] = [self stringWithStdString:*(alarm->picurlArray.at(j))];
                    }
                    alarmInfo->localDate = [self stringWithStdString:alarm->localDate];
                    [msgInfo_Out addObject:alarmInfo];
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)deleteAlarmMsg:(int64_t)alarmId Msg:(NSString**)errMsg_Out
{
    DeleteAlarmMessageRequest req;
    DeleteAlarmMessageResponse resp;
    req.data.token = m_accessToken;
    req.data.indexId = alarmId;
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                NSLog(@"deleteAlarmMsg [%lld] success", alarmId);
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getRecordNum:(NSString*)devID_In Chnl:(NSInteger)iCh_In Begin:(NSString*)beginTime_In End:(NSString*)endTime_In Num:(NSInteger*)num_Out Msg:(NSString**)errMsg_Out
{
    char strCh[10] = { 0 };
    snprintf(strCh, sizeof(strCh) - 1, "%ld", (long)iCh_In);
    
    QueryLocalRecordNumRequest req;
    QueryLocalRecordNumResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = strCh;
    req.data.beginTime = [beginTime_In UTF8String];
    req.data.endTime = [endTime_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                NSLog(@"getRecordNum num[%d]", resp.data.recordNum);
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
                *num_Out = resp.data.recordNum;
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getRecords:(NSString*)devID_In Chnl:(NSInteger)iCh_In Begin:(NSString*)beginTime_In End:(NSString*)endTime_In IndexBegin:(NSInteger)beginIndex_In IndexEnd:(NSInteger)endIndex_In InfoOut:(NSMutableArray*)info_Out Msg:(NSString**)errMsg_Out
{
    char strCh[10] = { 0 };
    char strRange[100] = { 0 };
    snprintf(strCh, sizeof(strCh) - 1, "%ld", (long)iCh_In);
    snprintf(strRange, sizeof(strRange) - 1, "%ld-%ld", (long)beginIndex_In, (long)endIndex_In);
    
    QueryLocalRecordsRequest req;
    QueryLocalRecordsResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = strCh;
    req.data.beginTime = [beginTime_In UTF8String];
    req.data.endTime = [endTime_In UTF8String];
    req.data.queryRange = strRange;
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:60];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int i = 0; i < resp.data.records.size(); i++) {
                    RecordInfo* recordInfo = [[RecordInfo alloc] init];
                    QueryLocalRecordsResponseData_RecordsElement *record = resp.data.records.at(i);
                    recordInfo->name = [self stringWithStdString:record->recordId];
                    recordInfo->beginTime = [self stringWithStdString:record->beginTime];
                    recordInfo->endTime = [self stringWithStdString:record->endTime];
                    recordInfo->size = record->fileLength;
                    [info_Out addObject:recordInfo];
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getCloudRecordNum:(NSString*)devID_In Chnl:(NSInteger)iCh_In Bengin:(NSString*)beginTime_In End:(NSString*)endTime_In Num:(NSInteger*)num_Out Msg:(NSString**)errMsg_Out
{
    char iCh[20] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    
    QueryCloudRecordNumRequest req;
    QueryCloudRecordNumResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    req.data.beginTime = [beginTime_In UTF8String];
    req.data.endTime = [endTime_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *num_Out = resp.data.recordNum;
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getCloudRecords:(NSString*)devID_In Chnl:(NSInteger)iCh_In Begin:(NSString*)beginTime_In End:(NSString*)endTime_In IndexBegin:(NSInteger)beginIndex_In IndexEnd:(NSInteger)endIndex_In InfoOut:(NSMutableArray*)info_Out Msg:(NSString**)errMsg_Out
{
    char iCh[20] = { 0 };
    char strRange[50] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    snprintf(strRange, sizeof(strRange) - 1, "%ld-%ld", (long)beginIndex_In, (long)endIndex_In);
    
    QueryCloudRecordsRequest req;
    QueryCloudRecordsResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    req.data.queryRange = strRange;
    req.data.beginTime = [beginTime_In UTF8String];
    req.data.endTime = [endTime_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                for (int i = 0; i < resp.data.records.size(); i++) {
                    RecordInfo* recordInfo = [[RecordInfo alloc] init];
                    QueryCloudRecordsResponseData_RecordsElement *record = resp.data.records.at(i);
                    
                    recordInfo->beginTime = [self stringWithStdString:record->beginTime];
                    recordInfo->endTime = [self stringWithStdString:record->endTime];
                    recordInfo->name = [NSString stringWithFormat:@"%@-%@", recordInfo->beginTime, recordInfo->endTime];
                    recordInfo->thumbUrl = [self stringWithStdString:record->thumbUrl];
                    recordInfo->size = atoi(record->size.c_str());
                    recordInfo->recId = [self stringWithStdString:resp.data.records.at(i)->recordId];
                    [info_Out addObject:recordInfo];
                }
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)controlPTZ:(NSString*)devID_In Chnl:(NSInteger)iCh_In Operate:(NSString*)strOperate_In Horizon:(double)iHorizon_In Vertical:(double)iVertical_In Zoom:(double)iZoom_In Duration:(NSInteger)iDuration_In Msg:(NSString**)errMsg_Out
{
    char iCh[10] = { 0 };
    char strDuration[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    snprintf(strDuration, sizeof(strDuration) - 1, "%ld", (long)iDuration_In);
    
    ControlPTZRequest req;
    ControlPTZResponse resp;
    req.data.deviceId = [devID_In UTF8String];
    req.data.duration = strDuration;
    req.data.channelId = iCh;
    req.data.h = iHorizon_In;
    req.data.v = iVertical_In;
    req.data.z = iZoom_In;
    req.data.operation = [strOperate_In UTF8String];
    req.data.token = m_accessToken;
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];

    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)modifyDeviceAlarmStatus:(NSString*)devID_In Chnl:(NSInteger)iCh_In Enable:(BOOL)enable_In Msg:(NSString**)errMsg_Out
{
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    
    ModifyDeviceAlarmStatusRequest req;
    ModifyDeviceAlarmStatusResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    req.data.enable = enable_In;
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)setStorageStrategy:(NSString*)devID_In Chnl:(NSInteger)iCh_In Enable:(NSString*)enable_In Msg:(NSString**)errMsg_Out
{
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    
    SetStorageStrategyRequest req;
    SetStorageStrategyResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    req.data.status = [enable_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];

    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)setAllStorageStrategy:(NSString*)devID_In Chnl:(NSInteger)iCh_In Enable:(NSString*)enable_In Msg:(NSString**)errMsg_Out
{
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    
    SetAllStorageStrategyRequest req;
    SetAllStorageStrategyResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    req.data.status = [enable_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)getStorageStrategy:(NSString*)devID_In Chnl:(NSInteger)iCh_In Msg:(NSString**)errMsg_Out
{
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    
    GetStorageStrategyRequest req;
    GetStorageStrategyResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

- (BOOL)modifyDevicePwd:(NSString *)devID_In oldPwd:(NSString *)oldPwd newPwd:(NSString *)newPwd
                    Msg:(NSString **)errMsg_Out;
{
    ModifyDevicePwdRequest req;
    ModifyDevicePwdResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.oldPwd = [oldPwd UTF8String];
    req.data.newPwd = [newPwd UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
};

- (BOOL)upgradeDevice:(NSString *)devID_In Msg:(NSString **)errMsg_Out
{
    UpgradeDeviceRequest req;
    UpgradeDeviceResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

- (BOOL)upgradeProcessDevice:(NSString *)devID_In Msg:(NSString **)errMsg_Out InfoOut:(DeviceUpgradeProcess*)info_Out;
{
    UpgradeProcessDeviceRequest req;
    UpgradeProcessDeviceResponse resp;
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    NSInteger ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                info_Out.version = [self stringWithStdString:resp.data.version];
                info_Out.status = [self stringWithStdString:resp.data.status];
                info_Out.percent = [self stringWithStdString:resp.data.percent];
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

#pragma mark - 获取呼吸灯的状态
- (BOOL)getDeviceBreatheLightWithDeviceIDStr:(NSString *)deviceID Status:(NSString *)status lc_Token:(NSString *)token Msg:(NSString**)errMsg_Out block:(void(^)(NSString *str))block
{
    BreathingLightStatusRequest  req ;
    BreathingLightStatusResponse  resp;
    NSInteger ret = 0;
    req.data.token = m_accessToken;
    req.data.deviceId = [deviceID UTF8String];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
                NSString * sta = [self stringWithStdString:resp.data.status];
                if (block) {
                block(sta);
                }
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

#pragma mark - 画面翻转
/**
 画面翻转
 
 @param devID_In 设备ID
 @param iCh_In 设备通道信号
 @param errMsg_Out 错误信息
 @return 返回是否请求成功
 */
- (BOOL)getFrameReverseStatusWithdeviceIDString:(NSString *)devID_In chnelInteger:(NSInteger)iCh_In Msg:(NSString**)errMsg_Out block:(void(^)(NSString *status))block;
{
    FrameReverseStatusRequest req;
    FrameReverseStatusResponse resp;
    NSInteger ret = 0;
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    // LeLog(@"m_hc=====%@", m_hc);
    ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
                NSString * result = [self stringWithStdString:resp.data.direction];
                if (block) {
                    block(result);
                }
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    
    return (0 == ret) ? YES : NO;
}

#pragma mark - 设置画面翻转
/**
 设置画面翻转
 
 @param devID_In 设备ID
 @param iCh_In 设备通道信号
 @param errMsg_Out 错误信息
 @return 返回是否请求成功
 */
- (BOOL)modifyFrameReverseStatusWithdeviceIDString:(NSString *)devID_In chnelInteger:(NSInteger)iCh_In Msg:(NSString**)errMsg_Out direction:(NSString *)direction block:(void(^)(BOOL status))block;
{
    ModifyFrameReverseStatusRequest req;
    ModifyFrameReverseStatusResponse resp;
    NSInteger ret = 0;
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);

    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    req.data.direction = [direction UTF8String];
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
                if(block) {
                    block(YES);
                }
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
                if(block) {
                    block(NO);
                }
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            if(block) {
                block(NO);
            }
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
        if(block) {
            block(NO);
        }
    }
    
    return (0 == ret) ? YES : NO;
}

#pragma mark - 修改设备名称
- (BOOL)modifyDeviceNameWithDeviceIDStr:(NSString *)deviceID Chnl:(NSInteger)iCh_In name:(NSString *)name  lc_Token:(NSString *)token Msg:(NSString**)errMsg_Out
{
    ModifyDeviceNameRequest req;
    ModifyDeviceNameResponse resp;
    NSInteger ret = 0;
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    req.data.token = m_accessToken;
    req.data.deviceId = [deviceID UTF8String];
    req.data.channelId = iCh;
    req.data.name = [name UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

#pragma mark - 修改呼吸灯的状态
- (BOOL)modifyDeviceBreatheLightWithDeviceIDStr:(NSString *)deviceID Status:(NSString *)status lc_Token:(NSString *)token Msg:(NSString**)errMsg_Out
{
    ModifyBreathingLightRequest  req;
    ModifyBreathingLightResponse  resp;
    NSInteger ret = 0;
    //char iCh[10] = { 0 };
    //snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    req.data.token = m_accessToken;
    req.data.deviceId = [deviceID UTF8String];
    req.data.status = [status UTF8String];
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}

#pragma mark - 初始化SD卡
- (BOOL)recoverSDCardWithdeviceIDString:(NSString *)devID_In chnelInteger:(NSInteger)iCh_In Msg:(NSString**)errMsg_Out
{
    RecoverSDCardRequest req;
    RecoverSDCardResponse resp;
    
    NSInteger ret = 0;
    char iCh[10] = { 0 };
    snprintf(iCh, sizeof(iCh) - 1, "%ld", (long)iCh_In);
    req.data.token = m_accessToken;
    req.data.deviceId = [devID_In UTF8String];
    req.data.channelId = iCh;
    
    *errMsg_Out = [INTERFACE_FAILED mutableCopy];
    
    ret = [m_hc request:&req resp:&resp timeout:10];
    if (0 == ret) {
        if (HTTP_OK == resp.code) {
            NSString* ret_code = [self stringWithStdString:resp.ret_code];
            if ([ret_code isEqualToString:@"0"]) {
                *errMsg_Out = [MSG_SUCCESS mutableCopy];
            } else {
                *errMsg_Out = [self stringWithStdString:resp.ret_msg];
            }
        } else {
            *errMsg_Out = [self stringWithStdString:resp.ret_msg];
        }
    } else {
        *errMsg_Out = [NETWORK_TIMEOUT mutableCopy];
    }
    return (0 == ret) ? YES : NO;
}


@end
