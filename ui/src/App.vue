<template>
  <div class="taxi-hud-wrapper">
    <!-- Main HUD -->
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

    <!-- Compact Popup in the Center -->
    <Transition name="fade">
      <div v-if="showPopup" class="popup-overlay">
        <div class="popup-card">
          <div class="popup-header">
            <span class="popup-brand">F17 TAXI</span>
            <span class="popup-title">{{ popupType === 'upgrade' ? 'DỊCH VỤ NHANH CHÓNG' : 'XÁC NHẬN HỦY CHẾ ĐỘ' }}</span>
          </div>
          <div class="popup-content">
            <template v-if="popupType === 'upgrade'">
              Bạn có đồng ý chuyển sang chế độ <span class="highlight-red">Quái Xế</span> để đến nơi nhanh chóng?
              <div class="price-info">
                Phụ phí: <span class="highlight-green">${{ additionalPrice }}</span> (khoảng 50% tiền đường đi)
              </div>
            </template>
            <template v-else>
              Bạn có chắc chắn muốn trở về chế độ <span class="highlight-normal">Bình thường</span> không?
              <div class="price-info highlight-red-warning">
                Lưu ý: Bạn sẽ không được hoàn lại số tiền phụ phí quái xế đã thanh toán.
              </div>
            </template>
          </div>
          <div class="popup-actions">
            <button class="btn btn-agree" @click="handleResponse(true)">
              {{ popupType === 'upgrade' ? 'Đồng ý' : 'Xác nhận' }}
            </button>
            <button class="btn btn-decline" @click="handleResponse(false)">
              {{ popupType === 'upgrade' ? 'Từ chối' : 'Hủy bỏ' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const visible = ref(false)
const driverName = ref('')
const fare = ref(0)
const speedStatus = ref('normal') // 'normal' | 'fast'
const showPopup = ref(false)
const additionalPrice = ref(0)
const popupType = ref('upgrade') // 'upgrade' | 'downgrade'

const speedText = computed(() => {
  if (speedStatus.value === 'fast') return 'Quái Xế'
  return 'Bình thường'
})

const speedClass = computed(() => {
  return {
    'speed-fast': speedStatus.value === 'fast',
    'speed-normal': speedStatus.value === 'normal'
  }
})

const handleResponse = (agree) => {
  showPopup.value = false
  const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'msk_aitaxi'
  fetch(`https://${resourceName}/crazyDriverResponse`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8'
    },
    body: JSON.stringify({ agree, type: popupType.value })
  }).catch(err => console.log('Error sending NUI callback:', err))
}

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
    showPopup.value = false
  } else if (data.action === 'updateSpeed') {
    speedStatus.value = data.speed
  } else if (data.action === 'showPopup') {
    popupType.value = data.type || 'upgrade'
    additionalPrice.value = Math.ceil((data.price || 0) * 0.5)
    showPopup.value = true
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
.taxi-hud-wrapper {
  position: relative;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
}

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

/* Popup Styles */
.popup-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.5); /* No filters used */
  display: flex;
  justify-content: center;
  align-items: center;
  pointer-events: auto;
  z-index: 9999;
}

.popup-card {
  width: 20vw;
  background: rgba(18, 18, 18, 0.98);
  border: 2px solid #ffc107;
  border-radius: 6px;
  padding: 2.5vh 1.8vw;
  color: #fff;
  font-family: 'Baloo 2', sans-serif;
  text-align: center;
  box-shadow: 0 0.8vh 2.4vh rgba(0, 0, 0, 0.75);
  animation: scaleUp 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.popup-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 2vh;
}

.popup-brand {
  font-size: 1.2vh;
  font-weight: 800;
  letter-spacing: 0.15vw;
  color: #ffc107;
  text-shadow: 0 0 0.4vh rgba(255, 193, 7, 0.4);
}

.popup-title {
  font-size: 1.5vh;
  font-weight: 700;
  color: #fff;
  margin-top: 0.2vh;
}

.popup-content {
  font-size: 1.35vh;
  line-height: 2.2vh;
  color: rgba(255, 255, 255, 0.85);
  margin-bottom: 2.5vh;
}

.price-info {
  margin-top: 1.5vh;
  font-size: 1.3vh;
  color: rgba(255, 255, 255, 0.6);
}

.highlight-red {
  color: #ff5252;
  font-weight: 800;
}

.highlight-green {
  color: #4caf50;
  font-weight: 800;
}

.popup-actions {
  display: flex;
  justify-content: center;
  gap: 0.8vw;
}

.btn {
  font-family: 'Baloo 2', sans-serif;
  font-size: 1.25vh;
  font-weight: 700;
  padding: 0.8vh 1.6vw;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-agree {
  background: #ffc107;
  color: #121212;
}

.btn-agree:hover {
  background: #ffb300;
  transform: scale(1.05);
}

.btn-decline {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.btn-decline:hover {
  background: rgba(255, 255, 255, 0.15);
  transform: scale(1.05);
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

@keyframes scaleUp {
  from {
    opacity: 0;
    transform: scale(0.9);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.highlight-normal {
  color: #ffc107;
  font-weight: 800;
}

.highlight-red-warning {
  color: #ff5252;
  margin-top: 1.5vh;
  font-size: 1.25vh;
  font-weight: 700;
}
</style>

