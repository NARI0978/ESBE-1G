#ifndef ESBE_UTIL_INCLUDED
#define ESBE_UTIL_INCLUDED

//=*=設定項目=*=
float blur = 0.00005;//影の境界ブラー(数が大きいほどぼやける)
//草木&水面の揺れ
#define LEAVES_WAVES
#define WATER_WAVES
#define WIND//揺れの揺らぎ
//水面反射
#define ESBE_WATER vec2(1.0,0.4)//波の縦横比
#define ESBE_HAN 0.85 //水面の雲の反射の程度。あげると強調。下げると控えめ。
#define C_REF//水面の雲の反射
//光源
#define ESBE_LIGHT vec3(0.95,0.65,0.3)
//陰
#define ESBE_SHADOW vec3(0.05,0.05,0.05)//影の色
#define ESBE_SIDE_SHADOW vec3(0.05,0.05,0.05)//ブロック側面の影の色
#define ESBE_SHADOW_DARKNESS 0.88//影の濃さ。あげると濃く、下げると薄く
#define ESBE_FLAT_SHADING//フラットシェーディング
//#define ESBE_UNEVEN 0.5//立体的なテクスチャ
#define EN_SH 0.85 //エンティティの横の明るさ。下げると暗く、あげると明るく
//日光
#define ESBE_SUN_LIGHT 0.83//昼間の明るさ向上
//夕焼け
#define DUSK 0.3//夕焼けの色の濃さ
float dusk1 = 0.25;//境界位置
float dusk2 = 0.25;//境界ブラー
//トーンマップ
#define ESBE_TONEMAP
#define TM_SATURATION 1.1//彩度
#define TM_EXPOSURE 1.5//露光
#define TM_BRIGHTNESS 0.6//明度
#define TM_GAMMA 0.88//ガンマ
#define TM_CONTRAST 0.95//コントラスト
//雲
#define RENDERCLOUDS 10//オクターブ
#define CLOUDS_DC vec3(1.3,1.3,1.1)//昼間の色
#define CLOUDS_SC vec3(1.4,1.0,0.6)//夕焼け時の色
#define CLOUDS_NC vec3(0.2,0.21,0.25)//夜間の色
#define NEW_CS//雲の影の演算
//オーロラ
#define RENDERAURORA 8.0//レイヤー数
#define AURORA_DS 2.5//レイヤー間の距離
#define AURORA_CC 0.2//レイヤー間色変化
#define AURORA_CS 6.0//色の濃さ

//自由にカスタムしてくださいな=*=-*-=*=

#endif
