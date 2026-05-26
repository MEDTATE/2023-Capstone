# OpenGL 기반 Anti-Aliasing 기법 구현 및 실시간 비교

OpenGL 4.5 환경에서 대표적인 Anti-Aliasing 기법 4가지를 직접 구현하고, 실시간으로 기법 간 품질과 성능을 비교할 수 있는 렌더러입니다.

---

## 주요 구현 기법

### MSAA (Multisample Anti-Aliasing)
- OpenGL 멀티샘플 프레임버퍼를 활용한 하드웨어 기반 AA
- 1X / 2X / 4X / 8X / 16X 샘플 수 실시간 변경 지원

### FXAA (Fast Approximate Anti-Aliasing)
- 포스트 프로세싱 기반 근사 AA
- 단일 패스로 처리되어 성능 부담이 낮음

### SMAA (Subpixel Morphological Anti-Aliasing)
- 엣지 검출 → 블렌딩 가중치 계산 → 이웃 블렌딩의 3-pass 파이프라인 구현
- LOW / MEDIUM / HIGH / ULTRA 4단계 품질 프리셋 지원
- Area LUT / Search LUT 텍스처 활용

### TAA (Temporal Anti-Aliasing)
- 할튼 수열 기반 서브픽셀 지터링으로 샘플 분산
- 이전 프레임 축적을 통한 시간적 블렌딩
- MSAA / FXAA / SMAA와 조합하여 사용 가능

---

## 주요 기능

- **실시간 기법 전환** — ImGui 패널에서 AA 기법을 즉시 전환하며 비교
- **Detail Screen** — 화면 일부를 확대하여 AA 적용 결과를 근접 확인
- **벤치마크** — 10초간 FPS를 측정하여 result.txt에 기록
- **씬 전환** — Container / Sponza 3D 모델, 합성 테스트 이미지 전환 지원
- **뷰포인트 프리셋** — 버튼 하나로 미리 설정된 카메라 위치로 이동

---

## 기술 스택

| 항목 | 내용 |
|------|------|
| 언어 | C++17 |
| 그래픽 API | OpenGL 4.5 |
| 윈도우/입력 | GLFW |
| UI | Dear ImGui |
| 수학 라이브러리 | GLM |
| 모델 로딩 | Assimp |
| 이미지 로딩 | stb_image |

---

## 프로젝트 구조

```
├── main.cpp                  # 진입점, 렌더 루프
├── FramebufferManager.h/.cpp # FBO·텍스처·RBO 생성 및 관리
├── AAPass.h/.cpp             # AA 기법별 렌더 패스
├── UIPanel.h/.cpp            # ImGui 컨트롤 패널
├── InputHandler.h/.cpp       # 키보드·마우스 입력 처리
└── shader/
    ├── basicModel.vs/fs      # 3D 모델 렌더링
    ├── fxaa_demo.vs/fs       # FXAA
    ├── smaaEdge.vs/fs        # SMAA 1패스: 엣지 검출
    ├── smaaBlendWeight.vs/fs # SMAA 2패스: 블렌딩 가중치
    ├── smaaNeighbor.vs/fs    # SMAA 3패스: 이웃 블렌딩
    └── temporal.vs/fs        # TAA 누적 블렌딩
```

---

## 빌드 환경

- Windows 10/11
- Visual Studio 2022
- OpenGL 4.5 이상 지원 GPU 필요

---

## 스크린샷

### 기법 비교 — Sponza Scene
![Sponza 비교](GPU%20Project/Benchmarks/Captures/comparison_sponza.png)

### 기법 비교 — Container Scene
![Container 비교](GPU%20Project/Benchmarks/Captures/comparison_container.png)

---

## 참고 자료

- [SMAA 논문 (Jimenez et al., 2012)](http://www.iryoku.com/smaa/)
- [FXAA - NVIDIA GameWorks Graphics Samples](https://github.com/ahcox/NVIDIA-GameWorks-Graphics-Samples-GL4-GLES2-GLES3-Vulkan-SDK-3-16-August-2017-36-Commits)
- [Temporal Anti-Aliasing(TAA) Tutorial - Sugu Lee](https://sugulee.wordpress.com/2021/06/21/temporal-anti-aliasingtaa-tutorial/)
- [LearnOpenGL](https://learnopengl.com)
- [Dear ImGui](https://github.com/ocornut/imgui)
- [GLFW](https://github.com/glfw/glfw)
- [GLM](https://github.com/g-truc/glm)
- [stb_image](https://github.com/nothings/stb)
- [Assimp](https://github.com/assimp/assimp)
