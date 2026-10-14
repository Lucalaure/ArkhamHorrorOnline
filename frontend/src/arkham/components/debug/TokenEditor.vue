<script lang="ts" setup>
/* A card's token pool in the debug windows: one shared amount box, a row per token
 * already on the card to add or take off that many, and a picker to place a token
 * the card does not have yet. Removing never asks for more than the card holds. */
import { computed, ref } from 'vue'
import { useDebug } from '@/arkham/debug'
import type { Game } from '@/arkham/types/Game'
import { TOKENS, type Token, type Tokens } from '@/arkham/types/Token'
import PoolItem from '@/arkham/components/PoolItem.vue'

type TokenTarget = { tag: string, contents: string }

const props = withDefaults(defineProps<{
  game: Game
  target: TokenTarget
  tokens: Tokens
  defaultToken?: Token
}>(), { defaultToken: 'Clue' })

const debug = useDebug()

/* The tokens that mean the same thing on every card come first in the picker, and
 * get their pool art in the rows; the rest are alphabetical. */
const COMMON: Token[] = ['Clue', 'Doom', 'Resource', 'Damage', 'Horror']
const POOL_TYPE: Partial<Record<Token, string>> = {
  Clue: 'clue', Doom: 'doom', Resource: 'resource', Damage: 'health', Horror: 'sanity',
}
const otherTokens = TOKENS.filter((t) => !COMMON.includes(t))

const amountInput = ref<number | string>(1)
const amount = computed(() => {
  const n = Math.floor(Number(amountInput.value))
  return Number.isFinite(n) && n > 0 ? n : 1
})
const PRESETS = [1, 3, 5, 10]

const newToken = ref<Token>(props.defaultToken)

const present = computed(() =>
  (Object.entries(props.tokens) as [Token, number | undefined][])
    .filter(([, n]) => (n ?? 0) > 0)
    .sort(([a], [b]) => {
      const ia = COMMON.indexOf(a), ib = COMMON.indexOf(b)
      if (ia !== -1 || ib !== -1) return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib)
      return a.localeCompare(b)
    }) as [Token, number][]
)

const label = (t: string) => t.replace(/([a-z])([A-Z])/g, '$1 $2')

function place(token: Token, n = amount.value) {
  debug.send(props.game.id, {
    tag: 'TokenMessage',
    contents: { tag: 'PlaceTokens_', contents: [{ tag: 'GameSource' }, props.target, token, n] },
  })
}

function remove(token: Token, n = amount.value) {
  const count = Math.min(n, props.tokens[token] ?? 0)
  if (count <= 0) return
  debug.send(props.game.id, {
    tag: 'TokenMessage',
    contents: { tag: 'RemoveTokens_', contents: [{ tag: 'GameSource' }, props.target, token, count] },
  })
}

function clearAll() {
  debug.send(props.game.id, {
    tag: 'TokenMessage',
    contents: { tag: 'ClearTokens_', contents: props.target },
  })
}

function nudgeAmount(by: number) {
  amountInput.value = Math.max(1, amount.value + by)
}
</script>

<template>
  <section class="token-editor">
    <div class="token-editor__header">
      <span class="token-editor__label">{{ $t('debug.tokens.title') }}</span>
      <div class="token-editor__amount">
        <span>{{ $t('debug.tokens.amount') }}</span>
        <button type="button" class="token-editor__step" @click="nudgeAmount(-1)">−</button>
        <input
          v-model="amountInput"
          type="number"
          min="1"
          step="1"
          inputmode="numeric"
          @focus="($event.target as HTMLInputElement).select()"
        />
        <button type="button" class="token-editor__step" @click="nudgeAmount(1)">+</button>
      </div>
    </div>
    <div class="token-editor__presets">
      <button
        v-for="p in PRESETS"
        :key="p"
        type="button"
        :class="{ 'token-editor__preset--active': amount === p }"
        @click="amountInput = p"
      >{{ p }}</button>
    </div>

    <p v-if="present.length === 0" class="token-editor__none">{{ $t('debug.tokens.none') }}</p>
    <ul v-else class="token-editor__rows">
      <li v-for="[token, count] in present" :key="token" class="token-editor__row">
        <span class="token-editor__name">
          <PoolItem v-if="POOL_TYPE[token]" :type="POOL_TYPE[token]!" />
          {{ label(token) }}
        </span>
        <span class="token-editor__count">{{ count }}</span>
        <button
          type="button"
          v-tooltip="$t('debug.tokens.remove', { amount: Math.min(amount, count), token: label(token) })"
          @click="remove(token)"
        >−{{ Math.min(amount, count) }}</button>
        <button
          type="button"
          v-tooltip="$t('debug.tokens.add', { amount, token: label(token) })"
          @click="place(token)"
        >+{{ amount }}</button>
        <button
          type="button"
          class="token-editor__clear"
          v-tooltip="$t('debug.tokens.removeEvery', { token: label(token) })"
          @click="remove(token, count)"
        ><font-awesome-icon icon="trash" /></button>
      </li>
    </ul>

    <div class="token-editor__add">
      <select v-model="newToken">
        <optgroup :label="$t('debug.tokens.common')">
          <option v-for="t in COMMON" :key="t" :value="t">{{ label(t) }}</option>
        </optgroup>
        <optgroup :label="$t('debug.tokens.other')">
          <option v-for="t in otherTokens" :key="t" :value="t">{{ label(t) }}</option>
        </optgroup>
      </select>
      <button type="button" class="token-editor__place" @click="place(newToken)">
        {{ $t('debug.tokens.place', { amount }) }}
      </button>
    </div>

    <button
      v-if="present.length > 0"
      type="button"
      class="token-editor__danger"
      @click="clearAll"
    >{{ $t('debug.common.removeAllTokens') }}</button>
  </section>
</template>

<style scoped>
/* Same section vocabulary as SealedTokensSection so the two stack as one tool. */
.token-editor {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 10px 12px;
  background: var(--box-background);
  border: 1px solid var(--box-border);
  border-radius: 6px;
  color: var(--text);
  font-size: 0.85rem;
  font-weight: normal;
  min-width: 240px;
}

.token-editor__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  flex-wrap: wrap;
}

.token-editor__label {
  font-family: teutonic, sans-serif;
  font-size: 0.95rem;
  letter-spacing: 0.04em;
  color: rgba(255, 255, 255, 0.72);
}

.token-editor__amount {
  display: flex;
  align-items: center;
  gap: 4px;
  color: rgba(255, 255, 255, 0.72);
  font-size: 0.8rem;
}

.token-editor__amount span {
  margin-right: 2px;
}

.token-editor input {
  width: 4.5em;
  padding: 5px 6px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 4px;
  background: var(--background-dark);
  color: var(--text);
  font-size: 0.85rem;
  text-align: center;
}

.token-editor input:focus {
  outline: none;
  border-color: var(--select);
}

.token-editor button,
.token-editor select {
  min-width: 0;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 4px;
  background: var(--background-dark);
  color: var(--text);
  font-size: 0.8rem;
  padding: 6px 10px;
  cursor: pointer;
  transition: background-color 0.12s ease, border-color 0.12s ease;
}

.token-editor button:hover {
  background: var(--button);
  border-color: var(--select);
}

.token-editor button.token-editor__step {
  width: 26px;
  height: 26px;
  padding: 0;
  display: grid;
  place-items: center;
}

.token-editor__presets {
  display: flex;
  gap: 4px;
  justify-content: flex-end;
}

.token-editor__presets button {
  padding: 2px 8px;
  font-size: 0.75rem;
}

.token-editor button.token-editor__preset--active {
  border-color: var(--select);
  background: color-mix(in srgb, var(--select) 25%, var(--background-dark));
}

.token-editor__none {
  margin: 0;
  color: rgba(255, 255, 255, 0.55);
}

.token-editor__rows {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.token-editor__row {
  --pool-token-width: 20px;
  display: grid;
  grid-template-columns: 1fr auto auto auto auto;
  align-items: center;
  gap: 6px;
}

.token-editor__name {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.token-editor__count {
  min-width: 2ch;
  text-align: right;
  font-weight: bold;
  font-variant-numeric: tabular-nums;
}

.token-editor__row button {
  padding: 4px 8px;
  min-width: 3em;
  font-variant-numeric: tabular-nums;
}

.token-editor__row button.token-editor__clear {
  min-width: 0;
  color: rgba(255, 255, 255, 0.6);
}

.token-editor__add {
  display: flex;
  gap: 6px;
}

.token-editor__add select {
  flex: 1;
  /* Extra right padding so the native chevron is not flush against the border. */
  padding-right: 14px;
}

.token-editor__place {
  white-space: nowrap;
}

.token-editor button.token-editor__danger:hover {
  background: #7a2020;
  border-color: #c05050;
}
</style>
