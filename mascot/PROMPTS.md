# Autophagy168 北极地松鼠 · 状态精灵生成计划

风格基准 = 用户 3 张参考（像素艺术 / 细腻毛发纹理 / 暖色绘本）。
一致性锚：先定稿「清醒态」隔离精灵 → 之后所有状态 `--ref` 它（+ 必要时用户图）。
全部要求：单只松鼠、全身、居中、**纯底无场景**、统一构图与缩放，方便 app 按状态切换 + 抠剪影。

固定角色块（每条前置）：
`16-bit pixel-art game sprite, a single chubby Arctic ground squirrel, sandy-tan dappled fur with fine texture, cream belly, small round ears, big black eyes, full cheeks, thick BUSHY tail with dark banding; full body, centered, ISOLATED on a plain flat solid background, NO scenery, crisp detailed pixel art, soft dark outline, warm storybook palette`

## 5 个 app 状态（代谢阶段）
1. **awake 清醒/警觉**（锚 & 进食窗口待机）：standing upright on hind legs, paws at chest, head up, bright-eyed, pale-cream background.
2. **fed 贴膘/进食**：sitting, very plump round belly, cheeks stuffed, holding a small berry in both paws, content happy eyes, warm peach background.
3. **digesting 消化**：sitting, drowsy half-closed eyes, one paw resting on full belly, tail starting to curl, warm amber background.
4. **torpor 深度蛰眠**：curled in a tight ball, the BUSHY BANDED TAIL WRAPPED FULLY AROUND the body like a blanket, one round ear poking up + nose tip tucked but visible, frost crystals on fur, cold blue background.
5. **arousal 唤醒/自噬**：uncurling and stretching with a little yawn, eyes opening, sparkle motes + faint glowing halo, violet-and-gold background, renewed/energized.

## 剪影小图标（息屏/刘海，单色、~20–40px 可读）
- 由定稿精灵抠/描成纯色剪影；2–3 个关键姿态：
  - `sil_awake` 直立警觉（进食/活跃）
  - `sil_curled` 蜷睡（断食/蛰眠）
  - `sil_spark` 唤醒带火花（自噬，可选）
- 单色 + 透明底，silhouette 必须靠**轮廓**就能认出松鼠（大尾巴翘起 / 蜷团带尾）。

## 自评分维度（每张，目标全部满意才算 100%）
a 像素风 ✓ · b 一眼是北极地松鼠 · c 与锚一致(同一只) · d 阶段语义清楚 · e 隔离可用(纯底统一构图) · f 剪影小尺寸可辨
