# SourceModPlugins-L4D2

#### 我自己私人搭建服务器的SourceMod插件合集，欢迎自取

```
Version 2.1.5.5 (left4dead2)
Network Version 2.0.4.2
Exe build: 14:46:56 Jul 16 2019 (7227) (550)
MetaMod Version: 1.10
SourceMod Version: 1.10.0.6453
L4D2ToolZ: 1.0.0.9h

SourceMod
SourceMod官网：https://www.sourcemod.net/
SourceMod下载：https://www.sourcemod.net/downloads.php?branch=stable

Metamod
Metamod官网：https://www.sourcemm.net/
生成对应游戏的VDF文件：https://www.sourcemm.net/vdf

L4DToolZ
L4DToolZ：https://forums.alliedmods.net/showthread.php?t=93600
L4DToolZ的GitHub：https://github.com/ivailosp/l4dtoolz/
```

#### 绝大部分来自于：

https://github.com/HMBSbige/SouceModPlugins

#### 插件说明：

| 插件文件名                     | 描述                      | 备注                                                         |
| :----------------------------- | :------------------------ | :----------------------------------------------------------- |
| advertisements.smx             | 广告插件                  |                                                              |
| all4dead2.smx                  | 额外的管理员菜单          | configs\advertisements.txt                                   |
| autoupdate.smx                 | all4dead2组件             | 不可删除                                                     |
| customvotes.smx                | 自定义投票菜单            | !votemenu, configs\customvotes.cfg                           |
| fix_l4dafkfix.smx              | 修复AFK BUG               |                                                              |
| GrabLasersight.smx             | 自动红外线                |                                                              |
| hostname.smx                   | 中文服务器名              |                                                              |
| item_give.smx                  | 管理员功能菜单            | !give                                                        |
| l4d2_autoIS.smx                | 多特感生成                |                                                              |
| l4d2_custom_commands.smx       | 更多玩家指令              | 菜单汉化, gamedata\l4d2_custom_commands.txt                  |
| l4d2_damage_sdkhooks.smx       | 武器伤害倍数              | configs\l4d2damagemod.cfg                                    |
| l4d2_freeroam.smx              | 观察者自由视角            | !freecam                                                     |
| l4d2_guncontrol.smx            | 枪械武器控制              | 修改备用弹药量、M60&榴弹枪子弹补充等, 需要搭配WeaponUnlock使用 |
| l4d2_kill_counter.smx          | 击杀统计                  | !counter, !kills, !teamkills, 默认开启友伤提示、关闭通知     |
| l4d2_meleemod.smx              | 近战武器控制              | 设置疲累值, 攻击间隔等                                       |
| l4d2_multislots.smx            | 多人BOT管理               | 中途玩家加入生成BOT提供接管, 自动踢出多余BOT                 |
| l4d2_reload_rate.smx           | 更改换弹速度              | 摘自Perkmod2源码                                             |
| l4d2_sgfix.smx                 | 修复sg552换弹bug          | SG552默认换弹动画结束到可开枪有延迟的BUG                     |
| l4d2_survivorai_triggerfix.smx | 全 Bot 队伍               |                                                              |
| l4d2_upgradepackfix.smx        | 多人配件 Bug 修复         |                                                              |
| l4d2_WeaponUnlock.smx          | 武器解锁                  | 搭配guncontrol使用                                           |
| l4dcsm_c.smx                   | 换角色或者外观            |                                                              |
| l4d_balance.smx                | 难度平衡系统              | 根据玩家危险系数更改导演AI运作(玩家过于安全则提高难度)       |
| l4d_botcreator.smx             | 多人自动添加 Bot          |                                                              |
| l4d_dissolve_infected.smx      | 感染者云消雾散            |                                                              |
| l4d_gear_transfer.smx          | R 键给物品、Bot自动给物品 |                                                              |
| l4d_hp_rewards.smx             | 击杀特感&Tank&Witch回血   | 原版消灭Tank&Witch只回复100HP, 改成与l4d_hp_rewards_max参数一致 |
| l4d_infectedhp.smx             | 显示特感&Tank&Witch血量   |                                                              |
| l4d_kill.smx                   | 自杀                      | !kill, !zs                                                   |
| l4d_multi_item.smx             | 多重补给                  | 修改地图生成的枪支、物品数量                                 |
| l4d_nightvision.smx            | 夜视仪                    | 双击手电筒开关(默认F键)                                      |
| l4d_sm_respawn.smx             | 复活指令                  | 嵌入管理员菜单                                               |
| l4d_stuckzombiemeleefix.smx    | Bug 修复                  |                                                              |
| l4d_survivorai_pouncedfix.smx  | 修复人工智障              |                                                              |
| playerinfo.smx                 | 玩家进入离开提示          |                                                              |
| R_UD_FF.smx                    | 友伤控制                  | 被特感控制时(解控后都有1秒的免友伤时间缓冲)、相互靠太近时、3.近战 |
| sm_autocb.smx                  | 自动Common Boost          | 求生KZ技巧, 踩头+右键瞬间加速, 默认开启                      |
| sm_bhop.smx                    | 自动连跳                  | !abh 开关, 默认开启                                          |
| sm_did.smx                     | 伤害显示                  | 包括友伤                                                     |
| sm_l4dvs_mapchanger.smx        | 终章投票+自动强制换图     | 取自[TW] Neptune 服, data\sm_l4d*_mapchanger.txt             |
| sv_steamgroup_fixer.smx        | 修复 Steam 组链接错误     |                                                              |
| tickrate.smx                   | 服务器Tickrate修改        | 运行参数加-tickrate 64, sm_gettickrate                       |