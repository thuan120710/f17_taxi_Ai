<template>
  <Transition name="slide">
    <div v-if="visible" class="taxi-hud-bar">
      <!-- Brand Logo -->
      <span class="brand-text">F17 TAXI</span>
      <div class="divider"></div>

      <!-- Driver -->
      <div class="info-item">
        <span class="label">Tài xế:</span>
        <span class="value gold">{{ driverName }}</span>
      </div>
      <div class="divider"></div>

      <!-- Fare -->
      <div class="info-item">
        <span class="label">Cước phí:</span>
        <span class="value green">${{ fare }}</span>
      </div>
      <div class="divider"></div>

      <!-- Speed -->
      <div class="info-item">
        <span class="label">Tốc độ:</span>
        <span class="value speed-val" :class="speedClass">{{ speedText }}</span>
      </div>
      <div class="divider"></div>

      <!-- Hotkey Guide -->
      <div class="key-guide">
        <span class="key">PgUp</span> <span>Tăng tốc</span>
        <span class="key">X</span> <span>Hủy</span>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const visible = ref(false)
const driverName = ref('')
const fare = ref(0)
const speedStatus = ref('normal') // 'normal' | 'fast'

const speedText = computed(() => {
  if (speedStatus.value === 'fast') return 'Phóng nhanh'
  return 'Bình thường'
})

const speedClass = computed(() => {
  return {
    'speed-fast': speedStatus.value === 'fast',
    'speed-normal': speedStatus.value === 'normal'
  }
})

const handleMessage = (event) => {
  const data = event.data
  if (!data) return

  if (data.action === 'show') {
    driverName.value = data.driver || 'Tài xế NPC'
    fare.value = data.price || 0
    speedStatus.value = data.speed || 'normal'
    visible.value = true
  } else if (data.action === 'hide') {
    visible.value = false
  } else if (data.action === 'updateSpeed') {
    speedStatus.value = data.speed
  }
}

onMounted(() => {
  window.addEventListener('message', handleMessage)
})

onUnmounted(() => {
  window.removeEventListener('message', handleMessage)
})
</script>

<style scoped>
.taxi-hud-bar {
  position: absolute;
  bottom: 3.5vh;
  left: 50%;
  transform: translate(-50%, 0);
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 0.8vw;
  background: rgba(18, 18, 18, 0.95);
  border: 1px solid rgba(255, 193, 7, 0.85); /* F17 Gold Border */
  border-radius: 4px;
  padding: 0.6vh 1vw;
  color: #fff;
  font-family: 'Baloo 2', sans-serif;
  font-size: 1.25vh;
  white-space: nowrap;
  pointer-events: none;
}

.divider {
  width: 1px;
  height: 1.6vh;
  background: rgba(255, 255, 255, 0.15);
}

.brand-text {
  font-size: 1.1vh;
  font-weight: 800;
  letter-spacing: 0.1vw;
  color: #ffc107; /* F17 Gold Yellow */
  text-shadow: 0 0 0.4vh rgba(255, 193, 7, 0.4);
}

.info-item {
  display: flex;
  align-items: center;
  gap: 0.35vw;
}

.label {
  color: rgba(255, 255, 255, 0.55);
}

.value {
  font-weight: 600;
}

.gold {
  color: #ffc107;
  text-shadow: 0 0 0.3vh rgba(255, 193, 7, 0.25);
}

.green {
  color: #4caf50;
  text-shadow: 0 0 0.3vh rgba(76, 175, 80, 0.25);
}

.speed-val {
  font-weight: 800;
}

.speed-normal {
  color: #fff;
}

.speed-fast {
  color: #ff5252;
  text-shadow: 0 0 0.4vh rgba(255, 82, 82, 0.4);
}

.key-guide {
  display: flex;
  align-items: center;
  gap: 0.3vw;
  font-size: 1.0vh;
  color: rgba(255, 255, 255, 0.55);
}

.key {
  background: #ffc107;
  color: #121212;
  padding: 0.15vh 0.35vw;
  border-radius: 2px;
  font-weight: 800;
  text-transform: uppercase;
}

/* Transitions */
.slide-enter-active,
.slide-leave-active {
  transition: all 0.25s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.slide-enter-from,
.slide-leave-to {
  opacity: 0;
  transform: translate(-50%, 1.5vh);
}
</style>
