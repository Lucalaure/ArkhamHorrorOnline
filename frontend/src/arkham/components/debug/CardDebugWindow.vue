<script lang="ts" setup>
/* The debug window for cards that had none: investigators, events, skills,
 * treacheries and stories. Same frame as the enemy window; the default slot
 * takes extra sections a card kind needs. Cards that hold tokens pass them in
 * and get the token editor; cards that can be attached pass `attachable`. */
import Draggable from '@/components/Draggable.vue'
import { useEscape } from '@/composable/escape'
import type { Game } from '@/arkham/types/Game'
import type { ChaosToken } from '@/arkham/types/ChaosToken'
import type { Token, Tokens } from '@/arkham/types/Token'
import type { Placement } from '@/arkham/types/Placement'
import type { AttachableTarget } from '@/arkham/debugAttach'
import type { SealableTarget } from '@/arkham/debugSeals'
import SealedTokensSection from '@/arkham/components/debug/SealedTokensSection.vue'
import TokenEditor from '@/arkham/components/debug/TokenEditor.vue'
import AttachSection from '@/arkham/components/debug/AttachSection.vue'

defineProps<{
  game: Game
  title: string
  image: string
  sealedTokens: ChaosToken[]
  target: SealableTarget
  tokens?: Tokens
  defaultToken?: Token
  attachable?: AttachableTarget
  placement?: Placement
}>()

const emit = defineEmits<{ close: [] }>()

useEscape(() => emit('close'))
</script>

<template>
  <Draggable>
    <template #handle><h2>{{ title }}</h2></template>
    <div class="debug-modal debug-window">
      <div class="card-debug">
        <img :src="image" class="card-debug__image card-no-overlay" />
        <div class="card-debug__panel">
          <slot />
          <AttachSection v-if="attachable" :game="game" :card="attachable" :placement="placement" />
          <TokenEditor v-if="tokens" :game="game" :tokens="tokens" :target="target" :defaultToken="defaultToken" />
          <SealedTokensSection :game="game" :tokens="sealedTokens" :target="target" />
        </div>
      </div>
      <button class="debug-close" @click="emit('close')">{{ $t('debug.common.close') }}</button>
    </div>
  </Draggable>
</template>

<style scoped>
.card-debug {
  display: flex;
  flex-flow: row wrap;
  gap: 12px;
  align-items: flex-start;
}

.card-debug__image {
  width: var(--card-width, 120px);
  max-width: 40vw;
  height: auto;
  border-radius: 6px;
}

.card-debug__panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
  min-width: 240px;
  max-width: 340px;
}
</style>
