<script lang="ts">
  import type { SessionMetrics } from '$lib/types';

  export let session: SessionMetrics | null;
  export let onClose: () => void;

  function formatDateTime(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleString([], {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }

  function handleBackdropClick(e: MouseEvent) {
    if (e.target === e.currentTarget) onClose();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if session}
  <div
    class="fixed inset-0 bg-crust/80 flex items-center justify-center z-50 p-4"
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
    role="dialog"
    aria-modal="true"
    tabindex="-1"
  >
    <div class="bg-bg-primary rounded-md max-w-md w-full border border-border-secondary">
      <!-- Header -->
      <div class="flex items-center justify-between px-3 py-2.5 border-b border-border-secondary">
        <div>
          <h2 class="text-sm font-semibold text-text-primary">Session Details</h2>
        </div>
        <button
          on:click={onClose}
          class="text-text-muted hover:text-text-primary transition-colors"
          aria-label="Close"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Session Info -->
      <div class="p-3 space-y-3">
        <div>
          <div class="text-xs text-text-muted uppercase tracking-wider mb-1">Project</div>
          <div class="text-sm font-medium text-sky">{session.project || 'Unknown'}</div>
          {#if session.projectPath}
            <div class="text-xs text-text-muted font-mono truncate" title={session.projectPath}>{session.projectPath}</div>
          {/if}
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <div class="text-xs text-text-muted uppercase tracking-wider mb-1">Session ID</div>
            <div class="text-xs font-mono text-text-secondary">{session.sessionId}</div>
          </div>
          <div>
            <div class="text-xs text-text-muted uppercase tracking-wider mb-1">Last Activity</div>
            <div class="text-xs text-text-primary">{formatDateTime(session.timestamp)}</div>
          </div>
        </div>

        <div>
          <div class="text-xs text-text-muted uppercase tracking-wider mb-1">Messages</div>
          <div class="text-lg font-bold text-text-primary">{session.messageCount}</div>
        </div>
      </div>
    </div>
  </div>
{/if}
