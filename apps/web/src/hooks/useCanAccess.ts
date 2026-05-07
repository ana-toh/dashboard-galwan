import { useCurrentUser } from "@/hooks/useCurrentUser"
import { AREAS } from "@/lib/permissions"
import type { ActionKey, AreaSlug } from "@/lib/permissions"

interface CanAccessResult {
  isLoading: boolean
  canAccess: (area: AreaSlug) => boolean
  canPerform: (area: AreaSlug, action: ActionKey) => boolean
  isAdmin: boolean
  isInactive: boolean
}

export const useCanAccess = (): CanAccessResult => {
  const { data: profile, isLoading } = useCurrentUser()

  const isAdmin = profile?.role === "admin"
  const isInactive = Boolean(profile && !profile.isActive)

  const canAccess = (area: AreaSlug): boolean => {
    if (!profile) return false
    if (!profile.isActive) return false
    if (isAdmin) return true
    return profile.permittedAreas.includes(area)
  }

  const canPerform = (area: AreaSlug, action: ActionKey): boolean => {
    if (!canAccess(area)) return false
    const allowed = AREAS[area].actions as readonly ActionKey[]
    return allowed.includes(action)
  }

  return { isLoading, canAccess, canPerform, isAdmin, isInactive }
}
