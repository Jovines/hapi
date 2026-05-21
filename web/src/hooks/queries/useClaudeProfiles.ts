import { useQuery } from '@tanstack/react-query'
import type { ApiClient } from '@/api/client'

export function useClaudeProfiles(api: ApiClient | null) {
    return useQuery({
        queryKey: ['claude-profiles'],
        queryFn: async () => {
            if (!api) return []
            const res = await api.getClaudeProfiles()
            return res.profiles ?? []
        },
        enabled: !!api,
        staleTime: 60_000
    })
}
