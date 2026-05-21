import { Hono } from 'hono'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'
import type { WebAppEnv } from '../middleware/auth'

function getProfilesPath(): string {
    const home = process.env.HAPI_HOME ?? join(homedir(), '.hapi')
    return join(home, 'claude-profiles.json')
}

export function createProfilesRoutes(): Hono<WebAppEnv> {
    const app = new Hono<WebAppEnv>()

    app.get('/claude-profiles', (c) => {
        const path = getProfilesPath()
        try {
            if (!existsSync(path)) {
                return c.json({ profiles: [] })
            }
            const raw = readFileSync(path, 'utf-8')
            const cfg = JSON.parse(raw)
            // Only return name + label, never expose command/env over API
            const profiles = (cfg.profiles ?? []).map((p: any) => ({
                name: p.name ?? 'unknown',
                label: p.label ?? p.name ?? 'unknown'
            }))
            return c.json({ profiles })
        } catch {
            return c.json({ profiles: [] })
        }
    })

    return app
}
