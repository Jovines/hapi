/**
 * Claude profile resolution.
 *
 * Profiles are defined in ~/.hapi/claude-profiles.json:
 *   { "profiles": [{ "name": "default", "label": "Default" }, { "name": "qwen", "command": "/path/to/wrapper", "env": {...} }] }
 *
 * - HAPI_CLAUDE_PROFILE env var selects the profile at spawn time
 * - getDefaultClaudeCodePath() is still the fallback when no profile is set
 * - HAPI_CLAUDE_PATH overrides the profile's command if both are set
 */
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

export interface ClaudeProfile {
    name: string
    label: string
    command?: string
    env?: Record<string, string>
}

interface ProfilesConfig {
    profiles: ClaudeProfile[]
}

function getProfilesPath(): string {
    const home = process.env.HAPI_HOME ?? join(process.env.HOME ?? '/tmp', '.hapi')
    return join(home, 'claude-profiles.json')
}

function loadProfilesConfig(): ProfilesConfig | null {
    const path = getProfilesPath()
    try {
        if (!existsSync(path)) return null
        const raw = readFileSync(path, 'utf-8')
        return JSON.parse(raw) as ProfilesConfig
    } catch {
        return null
    }
}

/** Returns all configured profiles (name + label only). */
export function listProfiles(): ClaudeProfile[] {
    const cfg = loadProfilesConfig()
    if (!cfg?.profiles) return [{ name: 'default', label: 'Default Claude' }]
    return cfg.profiles
}

/** Resolve a profile by name, returning its command (if any) and env vars. */
export function resolveProfile(profileName?: string | null): {
    command?: string
    env?: Record<string, string>
} {
    if (!profileName || profileName === 'default') return {}
    const cfg = loadProfilesConfig()
    if (!cfg?.profiles) return {}
    const profile = cfg.profiles.find(p => p.name === profileName)
    if (!profile) return {}
    return { command: profile.command, env: profile.env }
}
