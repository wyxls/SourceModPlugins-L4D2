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
| admin_chatcolor.smx            | 管理员聊天                | 将管理员聊天信息颜色变更                                     |
| advertisements.smx             | 广告插件                  |                                                              |
| all4dead2.smx                  | 额外的管理员菜单          | 相关文件: configs\advertisements.txt                         |
| autoupdate.smx                 | all4dead2组件             | 不可删除                                                     |
| customvotes.smx                | 自定义投票菜单            | !votemenu 投票菜单, 修复投票冷却时间不生效bug, 相关文件: configs\customvotes.cfg |
| fix_l4dafkfix.smx              | 修复AFK BUG               | 相关文件: gamedata\l4dafkfix.txt                             |
| GrabLasersight.smx             | 自动红外线                |                                                              |
| hostname.smx                   | 中文服务器名              | 相关文件: configs\hostname\hostname.txt                      |
| item_give.smx                  | 管理员功能菜单            | !give                                                        |
| l4d2_autoIS_extend.smx         | 多特生成                  | 新增Tank在场时是否继续生成特感，根据存活玩家数量调整特感数量以及刷新间隔等功能, 相关参数: l4d2_ais_spawn_si_with_tank ,l4d2_ais_spawn_size_on_player, l4d2_ais_spawn_size_add_amount, l4d2_ais_time_on_player, l4d2_ais_time_reduce_amount |
| l4d2_custom_commands.smx       | 更多玩家指令              | 菜单汉化, 相关文件: gamedata\l4d2_custom_commands.txt        |
| l4d2_damage_sdkhooks.smx       | 武器伤害倍数              | 相关文件: configs\l4d2damagemod.cfg                          |
| l4d2_freeroam.smx              | 观察者自由视角            | !freecam 自由观察视角                                        |
| l4d2_guncontrol.smx            | 枪械武器控制              | 修改备用弹药量、M60&榴弹枪子弹补充等, 需要搭配WeaponUnlock使用 |
| l4d2_incap_magnum.smx          | 倒地马格南                | 倒地时武器切换成马格南 (默认只有近战会切换)                  |
| l4d2_infiniteammo.smx          | 无限子弹菜单              | 内嵌SM管理员菜单，提示信息小改                               |
| l4d2_kill_counter.smx          | 击杀统计&友伤提示         | !counter 开关, !kills 个人数据, !teamkills 团队数据, 默认开启友伤提示、关闭通知 |
| l4d2_lethal.smx                | 狙击枪电磁炮              | 保持蹲下蓄力满, 射出电磁炮, 增加仅限管理员使用参数以及对应权限要求, 相关参数: lethal_weapon (admin_overrides.cfg) |
| l4d2_meleemod.smx              | 近战武器控制              | 设置疲累值, 攻击间隔等                                       |
| l4d2_memorizer.smx             | 记忆恢复玩家状态          | 望夜防止4+角色装备混乱的原版, 无任何提示                     |
| l4d2_multislots.smx            | 多人BOT管理               | 中途玩家加入生成BOT提供接管, 自动踢出多余BOT                 |
| l4d2_reload_rate.smx           | 更改换弹速度              | 摘自Perkmod2源码                                             |
| l4d2_satellite_cn.smx          | 马格南卫星炮              | 装备马格南, 缩放键弹出菜单切换模式, 射出从天而降的攻击, 增加仅限管理员使用和管理员无限能量参数, 相关参数: magnum_satellite, magnum_satellite_unlimit (admin_overrides.cfg) |
| l4d2_sgfix.smx                 | 修复sg552换弹bug          | SG552默认换弹动画结束到可开枪有延迟的BUG                     |
| l4d2_survivorai_triggerfix.smx | 全 Bot 队伍               |                                                              |
| l4d2_upgradepackfix.smx        | 多人配件 Bug 修复         |                                                              |
| l4d2_vote_manager3.smx         | 投票管理                  | 添加权限o和p, 管理员防踢                                     |
| l4d2_WeaponUnlock.smx          | 武器解锁                  | 搭配guncontrol使用                                           |
| l4dcsm_c.smx                   | 换角色或者外观            |                                                              |
| l4d_balance_fix.smx            | 难度平衡系统              | 根据玩家危险系数更改导演AI运作(即玩家过于安全则提高难度), 修复玩家在安全区域仍会刷怪的问题 |
| l4d_blackandwhite.smx          | 黑白提示                  | 更改默认提示模式为聊天栏, 文本汉化                           |
| l4d_botcreator.smx             | 多人自动添加 Bot          |                                                              |
| l4d_dissolve_infected.smx      | 感染者云消雾散            |                                                              |
| l4d_gear_transfer.smx          | R 键给物品、Bot自动给物品 |                                                              |
| l4d_hp_rewards.smx             | 击杀特感&Tank&Witch回血   | 原版消灭Tank&Witch只回复100HP, 改成与l4d_hp_rewards_max参数一致 |
| l4d_infectedhp.smx             | 显示特感&Tank&Witch血量   |                                                              |
| l4d_kill.smx                   | 自杀                      | !zs 自杀                                                     |
| l4d_multi_item.smx             | 多重补给                  | 修改地图生成的枪支、物品数量                                 |
| l4d_nightvision.smx            | 夜视仪                    | 双击手电筒开关(默认F键)，与大部分HUD Mod冲突，建议不装       |
| l4d_sm_respawn.smx             | 复活指令                  | 内嵌管理员菜单—玩家菜单内                                    |
| l4d_stuckzombiemeleefix.smx    | Bug 修复                  |                                                              |
| l4d_survivorai_pouncedfix.smx  | 修复人工智障              |                                                              |
| playerinfo.smx                 | 玩家进入离开提示          |                                                              |
| R_UD_FF.smx                    | 友伤控制                  | 被特感控制时(解控后都有1秒的免友伤时间缓冲)、相互靠太近时、3.近战 |
| sm_autocb.smx                  | 自动Common Boost          | 求生KZ技巧, 踩头+右键瞬间加速, 默认开启                      |
| sm_bhop.smx                    | 自动连跳                  | !abh 开关, 默认开启                                          |
| sm_did.smx                     | 伤害显示                  | 包括友伤                                                     |
| sm_l4dvs_mapchanger.smx        | 终章投票+自动强制换图     | 取自[TW] Neptune 服, 相关文件: data\sm_l4d*_mapchanger.txt   |
| sv_steamgroup_fixer.smx        | 修复 Steam 组链接错误     |                                                              |
| tickrate.smx                   | 服务器Tickrate修改        | 运行参数加-tickrate 64, sm_gettickrate                       |