<script lang="ts" setup>
/* Attach this card to any other card on the table; once attached it can be
 * discarded from here too. A card already riding on this one (directly or further down) is
 * left out of the list: attaching onto it would make the two hold each other. */
import { computed, ref } from 'vue'
import { useDebug } from '@/arkham/debug'
import type { Game } from '@/arkham/types/Game'
import type { Placement } from '@/arkham/types/Placement'
import { cardName } from '@/arkham/cardDetails'
import { useCardStore } from '@/stores/cards'
import {
  attachMessage,
  discardMessage,
  placementHost,
  sameTarget,
  stackedOn,
  type AttachableTarget,
  type HostKind,
  type HostTarget,
} from '@/arkham/debugAttach'

const props = defineProps<{
  game: Game
  card: AttachableTarget
  placement?: Placement
}>()

const debug = useDebug()
const cards = useCardStore()

function nameOf(code: string): string {
  const found = cards.cards.find((card) => card.cardCode === code)
    ?? cards.cards.find((card) => card.cardCode === code.replace(/^c/, ''))
  return found ? cardName(found) : code
}

const key = (t: { tag: string, contents: string }) => `${t.tag}:${t.contents}`

/* This card and everything stacked on it. */
const blocked = computed(() => stackedOn(props.game, props.card))

type HostOption = { value: string, target: HostTarget, name: string }

const groups = computed(() => {
  const g = props.game
  const option = (tag: HostKind, contents: string, name: string): HostOption =>
    ({ value: key({ tag, contents }), target: { tag, contents }, name })
  const raw: { key: string, options: HostOption[] }[] = [
    { key: 'investigators', options: Object.values(g.investigators).filter((i) => !i.eliminated).map((i) => option('InvestigatorTarget', i.id, i.name.title)) },
    { key: 'locations', options: Object.values(g.locations).map((l) => option('LocationTarget', l.id, nameOf(l.cardCode))) },
    { key: 'enemies', options: Object.values(g.enemies).map((e) => option('EnemyTarget', e.id, nameOf(e.cardCode))) },
    { key: 'assets', options: Object.values(g.assets).map((a) => option('AssetTarget', a.id, nameOf(a.cardCode))) },
    { key: 'events', options: Object.values(g.events).map((e) => option('EventTarget', e.id, nameOf(e.cardCode))) },
    { key: 'treacheries', options: Object.values(g.treacheries).map((t) => option('TreacheryTarget', t.id, nameOf(t.cardCode))) },
    { key: 'acts', options: Object.values(g.acts).map((a) => option('ActTarget', a.id, nameOf(a.id))) },
    { key: 'agendas', options: Object.values(g.agendas).map((a) => option('AgendaTarget', a.id, nameOf(a.id))) },
  ]
  return raw
    .map((group) => ({
      ...group,
      options: group.options
        .filter((o) => !blocked.value.has(o.value))
        .sort((a, b) => a.name.localeCompare(b.name)),
    }))
    .filter((group) => group.options.length > 0)
})

const selected = ref('')
const selectedOption = computed(() =>
  groups.value.flatMap((group) => group.options).find((o) => o.value === selected.value) ?? null
)

const currentHost = computed(() => placementHost(props.placement))
const currentHostName = computed(() => {
  const host = currentHost.value
  if (!host) return null
  for (const group of groups.value) {
    const found = group.options.find((o) => sameTarget(o.target, host))
    if (found) return found.name
  }
  return host.contents
})

function attach() {
  const option = selectedOption.value
  if (!option) return
  debug.send(props.game.id, attachMessage(props.card, option.target))
  selected.value = ''
}

function discard() {
  debug.send(props.game.id, discardMessage(props.card))
}
</script>

<template>
  <section class="attach-section">
    <span class="attach-section__label">{{ $t('debug.attach.title') }}</span>
    <div v-if="currentHost" class="attach-section__row">
      <span class="attach-section__current">{{ $t('debug.attach.attachedTo', { name: currentHostName }) }}</span>
      <button type="button" class="attach-section__discard" @click="discard">{{ $t('debug.attach.discard') }}</button>
    </div>
    <div class="attach-section__row">
      <select v-model="selected" :aria-label="$t('debug.attach.chooseHost')">
        <option value="">{{ $t('debug.attach.chooseHost') }}</option>
        <optgroup v-for="group in groups" :key="group.key" :label="$t(`debug.attach.groups.${group.key}`)">
          <option v-for="option in group.options" :key="option.value" :value="option.value">{{ option.name }}</option>
        </optgroup>
      </select>
      <button type="button" class="attach-section__go" :disabled="!selectedOption" @click="attach">
        {{ $t('debug.attach.attach') }}
      </button>
    </div>
  </section>
</template>

<style scoped>
/* Same section vocabulary as SealedTokensSection and TokenEditor. */
.attach-section {
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

.attach-section__label {
  font-family: teutonic, sans-serif;
  font-size: 0.95rem;
  letter-spacing: 0.04em;
  color: rgba(255, 255, 255, 0.72);
}

.attach-section__row {
  display: flex;
  align-items: center;
  gap: 6px;
}

.attach-section__current {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.attach-section select {
  flex: 1;
  min-width: 0;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 4px;
  background: var(--background-dark);
  color: var(--text);
  font-size: 0.8rem;
  /* Extra right padding so the native chevron is not flush against the border. */
  padding: 6px 14px 6px 8px;
}

.attach-section button {
  min-width: 0;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 4px;
  background: var(--background-dark);
  color: var(--text);
  font-size: 0.8rem;
  padding: 6px 10px;
  cursor: pointer;
  white-space: nowrap;
  transition: background-color 0.12s ease, border-color 0.12s ease;
}

.attach-section button:hover:not(:disabled) {
  background: var(--button);
  border-color: var(--select);
}

.attach-section button.attach-section__discard:hover {
  background: #7a2020;
  border-color: #c05050;
}

.attach-section button:disabled {
  opacity: 0.4;
  cursor: default;
}
</style>
