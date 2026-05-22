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
import { logger } from '@/ui/logger'

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
    logger.debug(`[Profile] Loading config from: ${path}`)
    try {
        if (!existsSync(path)) {
            logger.debug(`[Profile] Config file not found at: ${path}`)
            return null
        }
        const raw = readFileSync(path, 'utf-8')
        const cfg = JSON.parse(raw) as ProfilesConfig
        logger.debug(`[Profile] Loaded ${cfg.profiles?.length ?? 0} profiles`)
        return cfg
    } catch (e) {
        logger.debug(`[Profile] Failed to load config: ${e}`)
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
    // Env var fallback for runner-spawned processes where CLI args may not parse
    const name = profileName || process.env.HAPI_CLAUDE_PROFILE || null
    if (!name || name === 'default') return {}
    const cfg = loadProfilesConfig()
    if (!cfg?.profiles) return {}
    const profile = cfg.profiles.find(p => p.name === name)
    if (!profile) return {}
    return { command: profile.command, env: profile.env }
}
