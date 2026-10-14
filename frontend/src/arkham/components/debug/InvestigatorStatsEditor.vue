<script lang="ts" setup>
/* An investigator's printed values -- health, sanity and the four skills -- in the
 * investigator debug window. These rewrite the base value itself (the engine's
 * DebugSetInvestigatorStat), so modifiers keep applying on top as they would to the
 * card. Lowering health or sanity under what has been taken defeats them. */
import { reactive, watch } from 'vue'
import { useDebug } from '@/arkham/debug'
import type { Game } from '@/arkham/types/Game'
import type { Investigator } from '@/arkham/types/Investigator'
import PoolItem from '@/arkham/components/PoolItem.vue'

const props = defineProps<{
  game: Game
  investigator: Investigator
}>()

const debug = useDebug()

type Stat = 'health' | 'sanity' | 'willpower' | 'intellect' | 'combat' | 'agility'

/* Skills draw their glyph from the global `*-icon` classes; health and sanity have
 * none there, so they borrow the pool art instead. */
const STATS: { key: Stat, tag: string, min: number, pool?: string }[] = [
  { key: 'willpower', tag: 'DebugStatWillpower', min: 0 },
  { key: 'intellect', tag: 'DebugStatIntellect', min: 0 },
  { key: 'combat', tag: 'DebugStatCombat', min: 0 },
  { key: 'agility', tag: 'DebugStatAgility', min: 0 },
  { key: 'health', tag: 'DebugStatHealth', min: 1, pool: 'health' },
  { key: 'sanity', tag: 'DebugStatSanity', min: 1, pool: 'sanity' },
]

/* What each box shows. Kept apart from the investigator so a half-typed value is
 * not overwritten by an unrelated update, and re-synced whenever the real value
 * changes. */
const drafts = reactive<Record<Stat, number | string>>({
  health: 0, sanity: 0, willpower: 0, intellect: 0, combat: 0, agility: 0,
})

watch(
  () => STATS.map(({ key }) => props.investigator[key]),
  () => { for (const { key } of STATS) drafts[key] = props.investigator[key] },
  { immediate: true },
)

function setStat(stat: (typeof STATS)[number], value: number) {
  const next = Math.max(stat.min, Math.floor(value))
  if (!Number.isFinite(next) || next === props.investigator[stat.key]) {
    drafts[stat.key] = props.investigator[stat.key]
    return
  }
  debug.send(props.game.id, {
    tag: 'DebugSetInvestigatorStat',
    contents: [props.investigator.id, stat.tag, next],
  })
}

function commit(stat: (typeof STATS)[number]) {
  setStat(stat, Number(drafts[stat.key]))
}

function reset() {
  debug.send(props.game.id, { tag: 'DebugResetInvestigatorStats', contents: props.investigator.id })
}
</script>

<template>
  <section class="stats-editor">
    <span class="stats-editor__label">{{ $t('debug.investigatorStats.title') }}</span>
    <p class="stats-editor__hint">{{ $t('debug.investigatorStats.hint') }}</p>
    <div class="stats-editor__grid">
      <div v-for="stat in STATS" :key="stat.key" class="stats-editor__row">
        <span class="stats-editor__name">
          <PoolItem v-if="stat.pool" :type="stat.pool" class="stats-editor__icon" />
          <span v-else class="stats-editor__icon" :class="[`${stat.key}-icon`, stat.key]" aria-hidden="true"></span>
          {{ $t(`debug.investigatorStats.${stat.key}`) }}
        </span>
        <button
          type="button"
          :disabled="investigator[stat.key] <= stat.min"
          @click="setStat(stat, investigator[stat.key] - 1)"
        >−</button>
        <input
          v-model="drafts[stat.key]"
          type="number"
          :min="stat.min"
          step="1"
          inputmode="numeric"
          :aria-label="$t(`debug.investigatorStats.${stat.key}`)"
          @focus="($event.target as HTMLInputElement).select()"
          @keydown.enter="($event.target as HTMLInputElement).blur()"
          @blur="commit(stat)"
        />
        <button type="button" @click="setStat(stat, investigator[stat.key] + 1)">+</button>
      </div>
    </div>
    <button type="button" class="stats-editor__reset" @click="reset">
      {{ $t('debug.investigatorStats.reset') }}
    </button>
  </section>
</template>

<style scoped>
/* Same section vocabulary as SealedTokensSection and TokenEditor. */
.stats-editor {
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
}

.stats-editor__label {
  font-family: teutonic, sans-serif;
  font-size: 0.95rem;
  letter-spacing: 0.04em;
  color: rgba(255, 255, 255, 0.72);
}

.stats-editor__hint {
  margin: 0;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.55);
}

.stats-editor__grid {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.stats-editor__row {
  display: grid;
  grid-template-columns: 1fr auto 4em auto;
  align-items: center;
  gap: 6px;
}

.stats-editor__name {
  display: flex;
  align-items: center;
  gap: 6px;
}

.stats-editor__icon {
  --pool-token-width: 18px;
  display: inline-grid;
  place-items: center;
  width: 22px;
  font-size: 1.05rem;
}

.stats-editor__icon.willpower { color: var(--willpower); }
.stats-editor__icon.intellect { color: var(--intellect); }
.stats-editor__icon.combat { color: var(--combat); }
.stats-editor__icon.agility { color: var(--agility); }

.stats-editor input {
  width: 100%;
  padding: 5px 6px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 4px;
  background: var(--background-dark);
  color: var(--text);
  font-size: 0.85rem;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.stats-editor input:focus {
  outline: none;
  border-color: var(--select);
}

.stats-editor button {
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

.stats-editor__row button {
  width: 26px;
  height: 26px;
  padding: 0;
  display: grid;
  place-items: center;
  font-size: 0.95rem;
}

.stats-editor button:hover:not(:disabled) {
  background: var(--button);
  border-color: var(--select);
}

.stats-editor button:disabled {
  opacity: 0.4;
  cursor: default;
}
</style>
