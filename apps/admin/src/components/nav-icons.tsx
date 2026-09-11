import {
  Activity,
  BarChart3,
  Bell,
  Building2,
  CalendarDays,
  Home,
  Image as ImageIcon,
  LayoutList,
  Ticket,
  TrendingUp,
  LogOut,
  MapPin,
  Megaphone,
  Plug,
  Plus,
  Scale,
  Search,
  Settings,
  Star,
  UserCircle,
  Users,
  Wallet,
} from "lucide-react";
import type { ComponentType } from "react";

type IconProps = { className?: string };

function wrap(Lucide: ComponentType<{ className?: string; strokeWidth?: number }>) {
  return function Wrapped({ className = "h-[18px] w-[18px]" }: IconProps) {
    return <Lucide className={className} strokeWidth={1.9} />;
  };
}

export const IconHome = wrap(Home);
export const IconBell = wrap(Bell);
export const IconCalendar = wrap(CalendarDays);
export const IconWallet = wrap(Wallet);
export const IconBuilding = wrap(Building2);
export const IconUsers = wrap(Users);
export const IconMap = wrap(MapPin);
export const IconImage = wrap(ImageIcon);
export const IconStar = wrap(Star);
export const IconChart = wrap(BarChart3);
export const IconActivity = wrap(Activity);
export const IconSettings = wrap(Settings);
export const IconPlus = wrap(Plus);
export const IconSearch = wrap(Search);
export const IconLogout = wrap(LogOut);
export const IconDispute = wrap(Scale);
export const IconIntegration = wrap(Plug);
export const IconProfile = wrap(UserCircle);
export const IconBanner = wrap(Megaphone);
export const IconAmenities = wrap(LayoutList);
export const IconCoupon = wrap(Ticket);
export const IconTrends = wrap(TrendingUp);

export const NAV_ICONS: Record<string, ComponentType<IconProps>> = {
  "/": IconHome,
  "/notifications": IconBell,
  "/bookings": IconCalendar,
  "/disputes": IconDispute,
  "/payments": IconWallet,
  "/integrations": IconIntegration,
  "/profile": IconProfile,
  "/calendar": IconCalendar,
  "/providers": IconUsers,
  "/properties": IconBuilding,
  "/map": IconMap,
  "/amenities": IconAmenities,
  "/coupons": IconCoupon,
  "/banners": IconBanner,
  "/reviews": IconStar,
  "/users": IconUsers,
  "/locations": IconMap,
  "/reports": IconChart,
  "/analytics": IconTrends,
  "/activity": IconActivity,
  "/settings": IconSettings,
};

/** Accent color per nav item — feeds `.icon-chip-*` for a vivid, scannable sidebar. */
export const NAV_COLORS: Record<string, string> = {
  "/": "indigo",
  "/notifications": "rose",
  "/bookings": "sky",
  "/disputes": "amber",
  "/payments": "teal",
  "/calendar": "violet",
  "/providers": "indigo",
  "/properties": "teal",
  "/map": "sky",
  "/amenities": "amber",
  "/coupons": "teal",
  "/banners": "violet",
  "/reviews": "amber",
  "/users": "indigo",
  "/locations": "sky",
  "/reports": "violet",
  "/analytics": "sky",
  "/activity": "rose",
  "/settings": "indigo",
  "/integrations": "teal",
};
