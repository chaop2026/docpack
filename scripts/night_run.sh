#!/bin/sh
# SafeFile JP 야간 무인 제작 런처 (launchd 가 부른다).
#
# 본보기는 ~/Projects/naeilalbum/scripts/promo/night_run.sh 다. 그쪽이 다섯 번의
# 교차검증을 거쳐 닫은 실패들을 **그대로** 들고 온다 — 다시 겪을 이유가 없다.
# 바뀐 것은 경로·런 이름·커밋 대상뿐이다.
#
# 🔴 **plist 에 명령을 길게 적지 않는다.** 여기 한 곳만 고치면 되게 둔다 —
#    plist 를 고치면 매번 다시 등록(bootout/bootstrap)해야 한다.
# 🔴 `claude` 는 **셸 별칭**이라 launchd 에서는 없다. 실제 진입점을 직접 부른다.
# ⚠️ launchd 는 로그인 셸 PATH 를 물려받지 않는다 — ffmpeg·node 경로를 적는다.
#    이 저장소의 썸네일·쇼츠 빌드는 ffmpeg/ffprobe 와 playwright(chrome 채널)를
#    둘 다 쓴다. 하나라도 없으면 카드가 조용히 안 만들어지는 것이 아니라
#    **만들어진 것처럼 보이는 실패**가 되므로, 아래에서 먼저 확인하고 로그에 적는다.
set -u

PROJECT="/Users/sunghoon/Projects/docpack"
NODE="/opt/homebrew/bin/node"
CLAUDE_CLI="/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

cd "$PROJECT" || exit 1
mkdir -p logs/night
LOG="logs/night/$(date '+%Y-%m-%d').log"

# ── 🔴 사람이 도는 런과 겹치지 않는다 ────────────────────────────────
#
# 대화형 세션이 같은 회차 폴더를 고치는 중에 야간 런이 끼어들면 **같은 파일을
# 두 프로세스가 쓴다.** 이 저장소에서 그 대상은 `content/jp/epNN/` 의
# thumb_*.png · thumbnails.json · short_ja.json · shorts.mp4 이고, 쇼츠 빌드는
# `epNN/.shorts/` 를 **통째로 지우고 다시 만드는 것으로 시작한다**
# (scripts/content/lib/shorts.mjs). 두 런이 겹치면 한쪽의 중간 프레임이
# 다른 쪽 밑에서 사라진다.
#
# ⇒ `logs/night/RUN.lock` 이 있고 **6시간 안에** 만들어졌으면 돌지 않는다.
#   6시간을 넘긴 lock 은 **잊고 간 것**으로 본다 — 안 그러면 한 번 죽은 세션이
#   야간 런을 영원히 막는다.
#
# 🔴🔴 **나이를 못 재면 「오래된 lock」이 아니라 「살아 있는 lock」으로 본다**
#    (fail-closed). `stat` 이 실패할 때 mtime 을 0 으로 떨어뜨리면 나이가
#    56년(1970년 기준)으로 계산돼 *"잊고 간 것"* 으로 읽히고, **살아 있는 사람
#    세션 위로 야간 런이 올라탄다.** 안전장치가 **틀린 방향으로 열린다.**
#    그리고 그런 날은 고장 났다는 것조차 보이지 않는다.
#    ⇒ **세 갈래**: ①못 잰다 → 건너뛴다 ②6시간 안 → 건너뛴다
#      ③6시간 넘음 → 잊고 간 것으로 보고 진행한다.
#
# 🔴 **lock 은 지우지 않는다 — 덮어쓴다** (작업 지시서 6절 · Justin 결정).
#    파일은 **하나만** 두고 내용을 바꾼다:
#        시작  `HELD <시각> <런 이름> <표>`
#        끝    `RELEASED <시각> <런 이름>`   (실패해도 쓴다)
#    지우는 방식이면 런이 죽었을 때 lock 이 남아 다음 런을 6시간 막고, 그걸 푸는
#    유일한 길이 **사람이 파일을 지우는 것**이 된다 — 이 저장소의 삭제 안전
#    정책 아래에서 에이전트는 지울 수 없다. 안전장치가 **일을 멈추는 장치**가 된다.
#
# 🔴🔴 **읽을 수 없는 첫 줄은 「살아 있는 lock」으로 본다**(fail-closed).
#    `HELD` 도 `RELEASED` 도 아니면 **무슨 상태인지 모르는 것**이고, 모를 때
#    고를 쪽은 *"누가 쓰는 중"* 이다.
#
# 🔴 **lock 내용을 로그에 그대로 넣지 않는다** — 제어문자가 섞이면 로그가
#    망가진다. DEL(0x7f)까지 턴다(`\000-\037` 만 적으면 DEL 이 남아 터미널에서
#    앞 글자를 지우고, 로그가 조용히 달라 보인다). 인쇄 가능한 글자만, 200자까지.
LOCK="logs/night/RUN.lock"
if [ -f "$LOCK" ]; then
  LOCK_NOTE=$(tr -d '\000-\037\177' < "$LOCK" 2>/dev/null | tr '\n' ' ' | cut -c1-200)
  LOCK_FIRST=$(head -1 "$LOCK" 2>/dev/null | tr -d '\000-\037\177')
  LOCK_STATE=""
  case "$LOCK_FIRST" in
    RELEASED*) LOCK_STATE="released" ;;
    HELD*)     LOCK_STATE="held" ;;
  esac

  if [ "$LOCK_STATE" = "" ]; then
    echo "════════ $(date '+%Y-%m-%d %H:%M') 야간 런 건너뜀 — $LOCK 의 첫 줄이 HELD/RELEASED 가 아니다 · 내용: $LOCK_NOTE" >> "$LOG"
    exit 0
  fi

  if [ "$LOCK_STATE" = "released" ]; then
    echo "$(date '+%Y-%m-%d %H:%M') $LOCK 이 RELEASED 다 — 진행한다 · 내용: $LOCK_NOTE" >> "$LOG"
  else
    # BSD(macOS) 는 `stat -f %m`, GNU 는 `stat -c %Y`. 둘 다 실패하면 **빈 값**으로
    # 둔다 — 0 으로 떨어뜨리지 않는다(위 fail-closed 주석).
    LOCK_MTIME=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || true)
    case "$LOCK_MTIME" in
      ''|*[!0-9]*)
        echo "════════ $(date '+%Y-%m-%d %H:%M') 야간 런 건너뜀 — $LOCK 의 나이를 못 쟀다(stat 실패) · 내용: $LOCK_NOTE" >> "$LOG"
        exit 0
        ;;
    esac

    AGE=$(( $(date +%s) - LOCK_MTIME ))
    if [ "$AGE" -lt 21600 ]; then
      echo "════════ $(date '+%Y-%m-%d %H:%M') 야간 런 건너뜀 — $LOCK 이 HELD ($(( AGE / 60 ))분 전 · 내용: $LOCK_NOTE)" >> "$LOG"
      exit 0
    fi
    echo "⚠️ $(date '+%Y-%m-%d %H:%M') $LOCK 이 HELD 인데 $(( AGE / 3600 ))시간 전 것이라 잊고 간 것으로 보고 진행한다 · 내용: $LOCK_NOTE" >> "$LOG"
  fi
fi

# 🔴 **여기서 lock 을 잡는다 — 건너뛰기 판정을 전부 지난 뒤에.**
#    판정보다 먼저 잡으면 **건너뛰는 런이 남의 HELD 를 덮어쓴다** — 사람 세션이
#    쥔 lock 을 야간 런이 자기 것으로 바꾸고 나서 "건너뛴다" 고 나가는 꼴이다.
#
# 🔴 **쓰고 나서 다시 읽어 「내가 이겼는지」 확인한다.**
#    판정(위)과 기록(아래) 사이에 창이 있어서, 두 런이 동시에 RELEASED 를 읽으면
#    **둘 다 통과**한다. launchd 가 같은 순간에 두 번 부르는 날이 그 날이다.
#    ⇒ 각자 **고유 표**(PID+시각)를 적고 잠깐 뒤 다시 읽어, 파일에 남은 표가
#      내 것이 아니면 **진 것으로 보고 물러난다.** 마지막에 쓴 하나만 돈다.
#
# ⚠️ **완전한 뮤텍스가 아니다 — 정직하게 적는다.** 진짜 상호배제는 `mkdir`/`flock`
#    처럼 **지워야 하는** 자물쇠가 필요한데, 이 저장소의 삭제 안전 정책에서는
#    에이전트가 그걸 풀 수 없다. 지금 방식은 **현실적인 창**(동시 기동)을 닫고,
#    남는 창은 "둘 다 확인을 마친 뒤에야 다음 쓰기가 오는" 밀리초 단위뿐이다.
CLAIM="$$-$(date '+%s')"
printf 'HELD %s night_run %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$CLAIM" > "$LOCK"
sleep 2
WINNER=$(head -1 "$LOCK" 2>/dev/null | tr -d '\000-\037\177')
case "$WINNER" in
  *"$CLAIM"*) : ;;   # 내 표가 남아 있다 — 내가 돈다
  *)
    echo "════════ $(date '+%Y-%m-%d %H:%M') 야간 런 건너뜀 — 다른 런이 같은 순간에 lock 을 가져갔다(내 표 $CLAIM 아님)" >> "$LOG"
    exit 0
    ;;
esac
# 🔴 **푸는 것도 내 표일 때만.** 진 런이 이긴 런의 HELD 를 RELEASED 로 바꿔 버리면
#    안 된다. `trap` 으로 건다 — 런이 죽어도(kill·전원·에러) RELEASED 가 찍힌다.
#    night_run.md 의 에이전트도 같은 줄을 쓰는데, 그건 **중복이 아니라 그물 둘**이다:
#    에이전트가 죽은 날은 에이전트가 쓰는 줄까지 가지 못한다.
trap 'if head -1 "$LOCK" 2>/dev/null | grep -q "'"$CLAIM"'"; then printf "RELEASED %s night_run\n" "$(date "+%Y-%m-%d %H:%M:%S")" > "$LOCK"; fi' EXIT HUP INT TERM

{
  echo "════════ $(date '+%Y-%m-%d %H:%M') 야간 런 시작 ════════"
  # 🔴 도구 확인은 **경고가 아니라 기록**이다. 없는 채로 돌면 「썸네일 0장」이
  #    「만들 것이 없었다」와 밖에서 같아 보인다.
  [ -x "$NODE" ] || echo "🔴 node 가 없다: $NODE"
  [ -f "$CLAUDE_CLI" ] || echo "🔴 claude CLI 가 없다: $CLAUDE_CLI"
  command -v ffmpeg  >/dev/null || echo "🔴 ffmpeg 가 PATH 에 없다 — 쇼츠 렌더가 실패한다"
  command -v ffprobe >/dev/null || echo "🔴 ffprobe 가 PATH 에 없다 — qa_video 가 길이를 못 잰다"
  [ -d test/safe/node_modules/playwright ] || echo "🔴 playwright 가 없다: test/safe/node_modules — 썸네일·쇼츠 둘 다 실패한다"

  "$NODE" "$CLAUDE_CLI" -p "$(cat agents/night_run.md)" \
      --dangerously-skip-permissions
  rc=$?
  echo "════════ $(date '+%Y-%m-%d %H:%M') 야간 런 끝 (rc=$rc) ════════"
} >> "$LOG" 2>&1
