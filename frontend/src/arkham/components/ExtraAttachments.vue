<script lang="ts" setup>
/* Cards attached to a host that the host's own template has no place for -- an
 * asset on an act, a skill on a location, anything on an event or treachery.
 * Normally only the debug attach can put them there, but without this they would
 * vanish from the table. `skip` names the kinds the host already draws. */
import { computed } from 'vue'
import type { Game } from '@/arkham/types/Game'
import { attachedTo, type AttachedCards, type HostTarget } from '@/arkham/debugAttach'
import Asset from '@/arkham/components/Asset.vue'
import Event from '@/arkham/components/Event.vue'
import Skill from '@/arkham/components/Skill.vue'
import Treachery from '@/arkham/components/Treachery.vue'

const props = withDefaults(defineProps<{
  game: Game
  playerId: string
  host: HostTarget
  skip?: (keyof AttachedCards)[]
}>(), { skip: () => [] })

const emit = defineEmits<{ choose: [value: number] }>()

const cards = computed(() => {
  const all = attachedTo(props.game, props.host)
  const keep = (kind: keyof AttachedCards) => (props.skip.includes(kind) ? [] : all[kind])
  return {
    assets: keep('assets'),
    events: keep('events'),
    skills: keep('skills'),
    treacheries: keep('treacheries'),
  }
})

const any = computed(() =>
  Object.values(cards.value).some((ids) => ids.length > 0)
)
</script>

<template>
  <div v-if="any" class="extra-attachments">
    <Asset
      v-for="id in cards.assets"
      :key="id"
      :asset="game.assets[id]"
      :game="game"
      :playerId="playerId"
      @choose="emit('choose', $event)"
    />
    <Event
      v-for="id in cards.events"
      :key="id"
      :event="game.events[id]"
      :game="game"
      :playerId="playerId"
      :attached="true"
      @choose="emit('choose', $event)"
    />
    <Skill
      v-for="id in cards.skills"
      :key="id"
      :skill="game.skills[id]"
      :game="game"
      :playerId="playerId"
      :attached="true"
      @choose="emit('choose', $event)"
    />
    <Treachery
      v-for="id in cards.treacheries"
      :key="id"
      :treachery="game.treacheries[id]"
      :game="game"
      :playerId="playerId"
      :attached="true"
      @choose="emit('choose', $event)"
    />
  </div>
</template>

<style scoped>
.extra-attachments {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}
</style>
