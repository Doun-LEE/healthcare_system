/// 브랜드별 대표 머신 라인업. 헬스장 기구를 "브랜드 → 모델"로 고를 수 있게 한다.
///
/// 각 모델은 앱의 기구 종류([EquipmentType])에 연결돼 운동이 그 기준으로 짜인다.
/// 브랜드 공식 카탈로그 전체가 아니라 국내 헬스장에서 흔한 대표 모델 위주이고,
/// 없는 모델은 기구 선택의 "직접 추가"로 이름 그대로 넣을 수 있다.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'equipment_models.dart';

class BrandModel {
  const BrandModel(this.name, this.type, this.mechanism, {this.extra = const [], this.perSide = false});
  final String name;
  final EquipmentType type;
  final LoadMechanism mechanism;

  /// 한 기구로 되는 다른 운동 종류(다기능 머신).
  final List<EquipmentType> extra;

  /// 좌우 따로 원판을 거는 기구라 '한쪽 기준'으로 보기 좋은 경우.
  final bool perSide;
}

class EquipmentBrand {
  const EquipmentBrand({
    required this.key,
    required this.name,
    required this.aliases,
    required this.models,
    this.note = '',
    this.style = ModelStyle.standard,
  });
  final String key;
  final String name;
  final List<String> aliases;
  final List<BrandModel> models;
  final String note;

  /// 대표 색상·프레임 스타일(헬스장마다 색 옵션이 다를 수 있어 기구별로 바꿀 수 있다).
  final ModelStyle style;

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) || aliases.any((a) => a.toLowerCase().contains(s));
  }
}

const _pin = LoadMechanism.pin;
const _plate = LoadMechanism.plate;

/// 핀(스택) 머신 표준 구성. 브랜드 대부분이 이 구성을 갖고 있다.
List<BrandModel> _selectorized(String prefix) => [
      BrandModel('$prefix 체스트 프레스', EquipmentType.chestPress, _pin),
      BrandModel('$prefix 인클라인 체스트 프레스', EquipmentType.inclineChestPress, _pin),
      BrandModel('$prefix 펙덱/리어델트', EquipmentType.pecDeck, _pin),
      BrandModel('$prefix 숄더 프레스', EquipmentType.shoulderPress, _pin),
      BrandModel('$prefix 레터럴 레이즈', EquipmentType.lateralRaiseMachine, _pin),
      BrandModel('$prefix 랫풀다운', EquipmentType.latPulldown, _pin),
      BrandModel('$prefix 시티드 로우', EquipmentType.chestSupportedRow, _pin),
      BrandModel('$prefix 풀오버', EquipmentType.pulloverMachine, _pin),
      BrandModel('$prefix 어시스트 풀업/딥', EquipmentType.assistedPullUp, _pin),
      BrandModel('$prefix 바이셉 컬', EquipmentType.bicepCurlMachine, _pin),
      BrandModel('$prefix 트라이셉 익스텐션', EquipmentType.tricepExtensionMachine, _pin),
      BrandModel('$prefix 시티드 딥', EquipmentType.dipMachine, _pin),
      BrandModel('$prefix 레그 프레스', EquipmentType.horizontalLegPress, _pin),
      BrandModel('$prefix 레그 익스텐션', EquipmentType.legExtension, _pin),
      BrandModel('$prefix 시티드 레그 컬', EquipmentType.legCurl, _pin),
      BrandModel('$prefix 라잉 레그 컬', EquipmentType.lyingLegCurl, _pin),
      BrandModel('$prefix 힙 어브덕터', EquipmentType.hipAbductor, _pin),
      BrandModel('$prefix 힙 어덕터', EquipmentType.hipAdductor, _pin),
      BrandModel('$prefix 글루트', EquipmentType.gluteKickback, _pin),
      BrandModel('$prefix 복근 크런치', EquipmentType.abCrunchMachine, _pin),
      BrandModel('$prefix 백 익스텐션', EquipmentType.backExtensionMachine, _pin),
      BrandModel('$prefix 토르소 로테이션', EquipmentType.torsoRotation, _pin),
      BrandModel('$prefix 케이블 크로스오버', EquipmentType.cableMachine, _pin),
    ];

/// 원판(플레이트 로디드) 머신 표준 구성.
List<BrandModel> _plateLoaded(String prefix) => [
      BrandModel('$prefix 체스트 프레스(플레이트)', EquipmentType.chestPressPlateLoaded, _plate),
      BrandModel('$prefix 인클라인 프레스(플레이트)', EquipmentType.chestPressPlateLoaded, _plate),
      BrandModel('$prefix 디클라인 프레스(플레이트)', EquipmentType.declineChestPress, _plate),
      BrandModel('$prefix 숄더 프레스(플레이트)', EquipmentType.shoulderPressPlateLoaded, _plate),
      BrandModel('$prefix 풀다운(플레이트)', EquipmentType.latPulldownPlateLoaded, _plate),
      BrandModel('$prefix 하이 로우', EquipmentType.highRow, _plate),
      BrandModel('$prefix 로우 로우', EquipmentType.lowRow, _plate),
      BrandModel('$prefix 티바 로우', EquipmentType.tBarRow, _plate),
      BrandModel('$prefix 45° 레그 프레스', EquipmentType.legPress, _plate),
      BrandModel('$prefix 핵 스쿼트', EquipmentType.hackSquat, _plate),
      BrandModel('$prefix 펜듈럼 스쿼트', EquipmentType.pendulumSquat, _plate),
      BrandModel('$prefix V 스쿼트', EquipmentType.vSquat, _plate),
      BrandModel('$prefix 벨트 스쿼트', EquipmentType.beltSquat, _plate),
      BrandModel('$prefix 힙 쓰러스트', EquipmentType.hipThrust, _plate),
      BrandModel('$prefix 시티드 카프', EquipmentType.seatedCalfRaise, _plate),
      BrandModel('$prefix 슈러그', EquipmentType.shrugMachine, _plate),
    ];

final equipmentBrands = <EquipmentBrand>[
  EquipmentBrand(
    key: 'drax',
    name: '디랙스 (DRAX)',
    style: const ModelStyle(frame: Color(0xFF1E1F22), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFF8E959C)),
    aliases: ['drax', '디렉스', '디랙스', '드랙스'],
    note: '국내 헬스장에 많은 국산 브랜드. 핀·원판 머신과 복합 머신이 많다.',
    models: [
      ..._selectorized('디랙스'),
      ..._plateLoaded('디랙스'),
      const BrandModel('디랙스 스미스 머신', EquipmentType.smithMachine, _plate),
      const BrandModel('디랙스 파워랙', EquipmentType.squatRack, LoadMechanism.free),
      const BrandModel('디랙스 멀티 힙', EquipmentType.multiHip, _pin),
      const BrandModel('디랙스 몬스터 글루트', EquipmentType.monsterGlute, _plate),
    ],
  ),
  EquipmentBrand(
    key: 'hammer',
    name: '해머스트렝스 (Hammer Strength)',
    style: const ModelStyle(frame: Color(0xFF1E1F22), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFFB4BAC1)),
    aliases: ['hammer', 'hammer strength', '해머', '해머스트렝스', '아이소래터럴', 'iso-lateral', 'mts'],
    note: '아이소래터럴(좌우 독립) 원판 머신과 MTS 라인이 대표적.',
    models: const [
      BrandModel('해머 아이소래터럴 체스트 프레스', EquipmentType.chestPressPlateLoaded, _plate),
      BrandModel('해머 아이소래터럴 인클라인 프레스', EquipmentType.chestPressPlateLoaded, _plate),
      BrandModel('해머 아이소래터럴 디클라인 프레스', EquipmentType.declineChestPress, _plate),
      BrandModel('해머 아이소래터럴 와이드 체스트', EquipmentType.chestPressPlateLoaded, _plate),
      BrandModel('해머 아이소래터럴 숄더 프레스', EquipmentType.shoulderPressPlateLoaded, _plate),
      BrandModel('해머 아이소래터럴 프론트 랫풀다운', EquipmentType.latPulldownPlateLoaded, _plate),
      BrandModel('해머 아이소래터럴 하이 로우', EquipmentType.highRow, _plate),
      BrandModel('해머 아이소래터럴 로우 로우', EquipmentType.lowRow, _plate),
      BrandModel('해머 아이소래터럴 로우', EquipmentType.chestSupportedRow, _plate),
      BrandModel('해머 아이소래터럴 레그 프레스', EquipmentType.legPress, _plate),
      BrandModel('해머 리니어 레그 프레스', EquipmentType.legPress, _plate),
      BrandModel('해머 핵 스쿼트', EquipmentType.hackSquat, _plate),
      BrandModel('해머 V 스쿼트', EquipmentType.vSquat, _plate),
      BrandModel('해머 그라운드베이스 스쿼트 런지', EquipmentType.beltSquat, _plate),
      BrandModel('해머 시티드 카프', EquipmentType.seatedCalfRaise, _plate),
      BrandModel('해머 닐링 레그 컬', EquipmentType.lyingLegCurl, _plate),
      BrandModel('해머 레그 익스텐션', EquipmentType.legExtension, _plate),
      BrandModel('해머 슈러그', EquipmentType.shrugMachine, _plate),
      BrandModel('해머 MTS 체스트 프레스', EquipmentType.chestPress, _pin),
      BrandModel('해머 MTS 숄더 프레스', EquipmentType.shoulderPress, _pin),
      BrandModel('해머 MTS 프론트 풀다운', EquipmentType.latPulldown, _pin),
      BrandModel('해머 MTS 로우', EquipmentType.chestSupportedRow, _pin),
      BrandModel('해머 MTS 바이셉 컬', EquipmentType.bicepCurlMachine, _pin),
      BrandModel('해머 MTS 트라이셉 익스텐션', EquipmentType.tricepExtensionMachine, _pin),
      BrandModel('해머 MTS 복근 크런치', EquipmentType.abCrunchMachine, _pin),
    ],
  ),
  EquipmentBrand(
    key: 'lifefitness',
    name: '라이프피트니스 (Life Fitness)',
    style: const ModelStyle(frame: Color(0xFFB4BAC1), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFF6E7378), shroud: true, shroudColor: Color(0xFF3A3F47)),
    aliases: ['life fitness', 'lifefitness', '라이프', '라이프피트니스', 'insignia', 'signature'],
    note: '인시그니아·시그니처 핀 머신 라인과 유산소 기구.',
    models: [
      ..._selectorized('라이프'),
      const BrandModel('라이프 트레드밀', EquipmentType.treadmill, LoadMechanism.none),
      const BrandModel('라이프 일립티컬', EquipmentType.elliptical, LoadMechanism.none),
      const BrandModel('라이프 업라이트 바이크', EquipmentType.bike, LoadMechanism.none),
      const BrandModel('라이프 리컴번트 바이크', EquipmentType.recumbentBike, LoadMechanism.none),
      const BrandModel('라이프 파워밀(천국의 계단)', EquipmentType.stairClimber, LoadMechanism.none),
    ],
  ),
  EquipmentBrand(
    key: 'technogym',
    name: '테크노짐 (Technogym)',
    style: const ModelStyle(frame: Color(0xFFD5D9DE), pad: Color(0xFF3A3A3A), padDark: Color(0xFF262626), accent: Color(0xFF8E959C), shroud: true, shroudColor: Color(0xFFE6E8EA)),
    aliases: ['technogym', '테크노짐', '테크노', 'selection', 'pure'],
    note: '셀렉션(핀)·퓨어(원판) 라인과 유산소 기구.',
    models: [
      ..._selectorized('테크노짐'),
      ..._plateLoaded('테크노짐 퓨어'),
      const BrandModel('테크노짐 스킬밀(커브드)', EquipmentType.curvedTreadmill, LoadMechanism.none),
      const BrandModel('테크노짐 트레드밀', EquipmentType.treadmill, LoadMechanism.none),
      const BrandModel('테크노짐 스킬로우', EquipmentType.rower, LoadMechanism.none),
    ],
  ),
  EquipmentBrand(
    key: 'cybex',
    name: '사이벡스 (Cybex)',
    style: const ModelStyle(frame: Color(0xFFA9AFB6), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFF5F656C), shroud: true, shroudColor: Color(0xFF2B2F36)),
    aliases: ['cybex', '사이벡스', 'eagle'],
    models: [
      ..._selectorized('사이벡스'),
      const BrandModel('사이벡스 아크 트레이너', EquipmentType.elliptical, LoadMechanism.none),
    ],
  ),
  EquipmentBrand(
    key: 'matrix',
    name: '매트릭스 (Matrix)',
    style: const ModelStyle(frame: Color(0xFF2B2E33), pad: Color(0xFF242424), padDark: Color(0xFF161616), accent: Color(0xFFB4BAC1), shroud: true, shroudColor: Color(0xFF1E1F22)),
    aliases: ['matrix', '매트릭스', 'ultra', 'magnum'],
    models: [
      ..._selectorized('매트릭스'),
      ..._plateLoaded('매트릭스 매그넘'),
      const BrandModel('매트릭스 클라임밀(천국의 계단)', EquipmentType.stairClimber, LoadMechanism.none),
    ],
  ),
  EquipmentBrand(
    key: 'panatta',
    name: '파나타 (Panatta)',
    style: const ModelStyle(frame: Color(0xFF151515), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFF9AA3AD)),
    aliases: ['panatta', '파나타'],
    note: '원판·핀 머신 모두 많고 스쿼트 계열 머신이 다양하다.',
    models: [..._selectorized('파나타'), ..._plateLoaded('파나타')],
  ),
  EquipmentBrand(
    key: 'gym80',
    name: '짐80 (gym80)',
    style: const ModelStyle(frame: Color(0xFF2D2D2D), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFFB4BAC1)),
    aliases: ['gym80', '짐80', '짐 80'],
    models: [..._selectorized('짐80'), ..._plateLoaded('짐80')],
  ),
  EquipmentBrand(
    key: 'lexco',
    name: '렉스코 (LEXCO)',
    style: const ModelStyle(frame: Color(0xFF1E1F22), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFF9AA3AD)),
    aliases: ['lexco', '렉스코', '렉스', '렉스코피트니스'],
    note: '국산 브랜드. 핀·원판 머신과 유산소 기구.',
    models: [
      ..._selectorized('렉스코'),
      ..._plateLoaded('렉스코'),
      const BrandModel('렉스코 스미스 머신', EquipmentType.smithMachine, _plate),
      const BrandModel('렉스코 파워랙', EquipmentType.squatRack, LoadMechanism.free),
      const BrandModel('렉스코 트레드밀', EquipmentType.treadmill, LoadMechanism.none),
      const BrandModel('렉스코 업라이트 바이크', EquipmentType.bike, LoadMechanism.none),
    ],
  ),
  EquipmentBrand(
    key: 'newtech',
    name: '뉴텍 (Newtech)',
    style: const ModelStyle(frame: Color(0xFF2B2E33), pad: Color(0xFF2A2A2A), padDark: Color(0xFF1A1A1A), accent: Color(0xFF9AA3AD)),
    aliases: ['newtech', '뉴텍'],
    note: '국산 브랜드.',
    models: [
      const BrandModel('뉴텍 멀티 해머 프레스(숄더·슈러그·로우·카프)', EquipmentType.shoulderPressPlateLoaded, _plate,
          extra: [EquipmentType.shrugMachine, EquipmentType.lowRow, EquipmentType.calfRaise], perSide: true),
      ..._selectorized('뉴텍'),
      ..._plateLoaded('뉴텍'),
    ],
  ),
  EquipmentBrand(
    key: 'cable',
    name: '프리모션 / 기타 케이블',
    style: ModelStyle.standard,
    aliases: ['freemotion', '프리모션', '케이블'],
    models: const [
      BrandModel('듀얼 케이블(펑셔널 트레이너)', EquipmentType.functionalTrainer, _pin),
      BrandModel('케이블 크로스오버', EquipmentType.cableMachine, _pin),
      BrandModel('멀티 스테이션', EquipmentType.multiStation, _pin),
    ],
  ),
];


EquipmentBrand? brandByKey(String? key) => key == null ? null : equipmentBrands.where((b) => b.key == key).firstOrNull;

/// 기구 하나의 3D 스타일: 브랜드 기본 → 사용자가 고른 색·커버로 덮어쓰기.
ModelStyle styleForEquipment(GymEquipment e) {
  final base = brandByKey(e.brand)?.style ?? ModelStyle.standard;
  if (e.frameColor == null && e.padColor == null && e.shroud == null) return base;
  return base.copyWith(
    frame: e.frameColor == null ? null : Color(e.frameColor!),
    pad: e.padColor == null ? null : Color(e.padColor!),
    shroud: e.shroud,
  );
}
