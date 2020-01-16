#ifndef ESBE_UTIL_INCLUDED
#define ESBE_UTIL_INCLUDED

//=*=設定項目=*=
	//blur設定はterrain.fsh.hlslの169行目にあります
//草木&水面の揺れ
#define LEAVES_WAVES
#define WATER_WAVES
#define WIND//揺れの揺らぎ
//水面反射
#define ESBE_WATER float2(1.0,0.5)//波の縦横比
#define C_REF//水面の雲の反射
//光源
#define ESBE_LIGHT float3(0.700,0.500,0.300)
//影
#define ESBE_SHADOW float3(0.0,0.0,0.0)
#define ESBE_SIDE_SHADOW float3(0.0,0.0,0.0)//ブロック側面の影
#define ESBE_FLAT_SHADING//フラットシェーディング
#define ESBE_UNEVEN 0.5//立体的なテクスチャ
//日光
#define ESBE_SUN_LIGHT 0.5//昼間の明るさ向上
//夕焼け
#define DUSK 0.3//夕焼けの色の濃さ
	//dusk1 dusk2など詳細設定は
	//terrain.fsh.hlslの169行目にあります
//トーンマップ
#define ESBE_TONEMAP
#define TM_SATURATION 1.2//彩度
#define TM_EXPOSURE 1.0//露光
#define TM_BRIGHTNESS 1.0//明度
#define TM_GAMMA 1.0//ガンマ
#define TM_CONTRAST 1.0//コントラスト
//オーロラ
#define RENDERAURORA 12.0//レイヤー数
#define AURORA_DS 2.0//レイヤー間の距離
#define AURORA_CC 0.1//レイヤー間色変化
#define AURORA_CS 3.0//色の濃さ
//雲
#define RENDERCLOUDS 8//オクターブ
#define CLOUDS_DC float3(1.3,1.3,1.1)//昼間の色
#define CLOUDS_SC float3(1.4,1.0,0.6)//夕焼け時の色
#define CLOUDS_NC float3(0.2,0.21,0.25)//夜間の色
#define NEW_CS//雲の影の演算
//=*=-*-=*=

#endif
