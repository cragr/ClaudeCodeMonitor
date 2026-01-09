<script lang="ts">
  import { TIME_RANGE_OPTIONS, type TimeRange, type CustomTimeRange } from '$lib/types';

  export let value: TimeRange;
  export let onChange: (value: TimeRange) => void;
  export let customRange: CustomTimeRange | null = null;
  export let onCustomRangeChange: (range: CustomTimeRange) => void = () => {};

  let showCustomPicker = false;
  let customStartDate = '';
  let customStartTime = '00:00';
  let customEndDate = '';
  let customEndTime = '23:59';

  // Initialize custom dates to sensible defaults when opening picker
  function initCustomDates() {
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    customEndDate = now.toISOString().split('T')[0];
    customEndTime = now.toTimeString().slice(0, 5);
    customStartDate = weekAgo.toISOString().split('T')[0];
    customStartTime = '00:00';

    // If we have existing custom range, use those values
    if (customRange) {
      const start = new Date(customRange.start * 1000);
      const end = new Date(customRange.end * 1000);
      customStartDate = start.toISOString().split('T')[0];
      customStartTime = start.toTimeString().slice(0, 5);
      customEndDate = end.toISOString().split('T')[0];
      customEndTime = end.toTimeString().slice(0, 5);
    }
  }

  function handleSelectChange(e: Event) {
    const target = e.target as HTMLSelectElement;
    const newValue = target.value as TimeRange;

    if (newValue === 'custom') {
      initCustomDates();
      showCustomPicker = true;
    } else {
      showCustomPicker = false;
      onChange(newValue);
    }
    value = newValue;
  }

  function applyCustomRange() {
    const startDateTime = new Date(`${customStartDate}T${customStartTime}`);
    const endDateTime = new Date(`${customEndDate}T${customEndTime}`);

    const range: CustomTimeRange = {
      start: Math.floor(startDateTime.getTime() / 1000),
      end: Math.floor(endDateTime.getTime() / 1000),
    };

    onCustomRangeChange(range);
    showCustomPicker = false;
    onChange('custom');
  }

  function cancelCustomRange() {
    showCustomPicker = false;
    // Revert to previous non-custom selection if we haven't applied a custom range
    if (!customRange) {
      value = '15m';
      onChange('15m');
    }
  }

  function formatCustomLabel(): string {
    if (!customRange) return 'Custom Range';
    const start = new Date(customRange.start * 1000);
    const end = new Date(customRange.end * 1000);
    const formatDate = (d: Date) => d.toLocaleDateString([], { month: 'short', day: 'numeric' });
    return `${formatDate(start)} - ${formatDate(end)}`;
  }

  // Close picker when clicking outside
  function handleClickOutside(e: MouseEvent) {
    const target = e.target as HTMLElement;
    if (!target.closest('.custom-picker-container')) {
      showCustomPicker = false;
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<div class="relative inline-block custom-picker-container">
  <select
    bind:value
    on:change={handleSelectChange}
    class="appearance-none bg-bg-card border border-border-secondary rounded-lg px-5 py-2.5 pr-10 text-base font-medium focus:outline-none focus:ring-1 focus:ring-blue min-w-[160px] cursor-pointer"
    style="color: #ffffff;"
  >
    {#each TIME_RANGE_OPTIONS as option}
      {#if option.value === 'custom' && customRange}
        <option value={option.value} style="background: #2c2c2e; color: #ffffff;">{formatCustomLabel()}</option>
      {:else}
        <option value={option.value} style="background: #2c2c2e; color: #ffffff;">{option.label}</option>
      {/if}
    {/each}
  </select>
  <!-- Custom dropdown arrow -->
  <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
    <svg class="w-4 h-4 text-text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
    </svg>
  </div>

  <!-- Custom date/time picker dropdown -->
  {#if showCustomPicker}
    <!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
    <div
      class="absolute top-full right-0 mt-2 bg-bg-card border border-border-secondary rounded-lg shadow-xl z-50 p-4 min-w-[320px]"
      on:click|stopPropagation
      role="dialog"
      aria-label="Custom time range picker"
      tabindex="-1"
    >
      <div class="text-sm font-medium text-text-primary mb-3">Custom Time Range</div>

      <!-- Start Date/Time -->
      <div class="mb-3">
        <span class="block text-xs text-text-muted mb-1">Start</span>
        <div class="flex gap-2">
          <input
            type="date"
            bind:value={customStartDate}
            aria-label="Start date"
            class="flex-1 bg-bg-primary border border-border-secondary rounded px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-1 focus:ring-blue"
            style="color-scheme: dark;"
          />
          <input
            type="time"
            bind:value={customStartTime}
            aria-label="Start time"
            class="w-24 bg-bg-primary border border-border-secondary rounded px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-1 focus:ring-blue"
            style="color-scheme: dark;"
          />
        </div>
      </div>

      <!-- End Date/Time -->
      <div class="mb-4">
        <span class="block text-xs text-text-muted mb-1">End</span>
        <div class="flex gap-2">
          <input
            type="date"
            bind:value={customEndDate}
            aria-label="End date"
            class="flex-1 bg-bg-primary border border-border-secondary rounded px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-1 focus:ring-blue"
            style="color-scheme: dark;"
          />
          <input
            type="time"
            bind:value={customEndTime}
            aria-label="End time"
            class="w-24 bg-bg-primary border border-border-secondary rounded px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-1 focus:ring-blue"
            style="color-scheme: dark;"
          />
        </div>
      </div>

      <!-- Buttons -->
      <div class="flex justify-end gap-2">
        <button
          on:click={cancelCustomRange}
          class="px-3 py-1.5 text-sm text-text-muted hover:text-text-primary transition-colors"
        >
          Cancel
        </button>
        <button
          on:click={applyCustomRange}
          class="px-4 py-1.5 text-sm font-medium bg-blue text-white rounded hover:bg-blue/80 transition-colors"
        >
          Apply
        </button>
      </div>
    </div>
  {/if}
</div>
