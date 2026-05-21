export function ProfileSelector(props: {
    profile: string
    profiles: { name: string; label: string }[]
    isDisabled: boolean
    isClaude: boolean
    onProfileChange: (value: string) => void
}) {
    // Only show for Claude agent
    if (!props.isClaude || props.profiles.length === 0) return null

    return (
        <div className="flex flex-col gap-1.5 px-3 py-3">
            <label className="text-xs font-medium text-[var(--app-hint)]">
                Claude Profile
            </label>
            <select
                value={props.profile}
                onChange={(e) => props.onProfileChange(e.target.value)}
                disabled={props.isDisabled}
                className="rounded-md border border-[var(--app-border)] bg-[var(--app-bg)] px-3 py-2 text-sm"
            >
                {props.profiles.map((p) => (
                    <option key={p.name} value={p.name}>
                        {p.label}
                    </option>
                ))}
            </select>
        </div>
    )
}
