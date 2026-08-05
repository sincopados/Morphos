export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.15"
  }
  public: {
    Tables: {
      admin_work_sites: {
        Row: {
          assigned_by: string
          company_id: string
          created_at: string
          id: string
          member_id: string
          work_site_id: string
        }
        Insert: {
          assigned_by: string
          company_id: string
          created_at?: string
          id?: string
          member_id: string
          work_site_id: string
        }
        Update: {
          assigned_by?: string
          company_id?: string
          created_at?: string
          id?: string
          member_id?: string
          work_site_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_work_sites_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_work_sites_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_work_sites_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_work_sites_work_site_id_fkey"
            columns: ["work_site_id"]
            isOneToOne: false
            referencedRelation: "work_sites"
            referencedColumns: ["id"]
          },
        ]
      }
      assigned_shifts: {
        Row: {
          assigned_by: string
          company_id: string
          created_at: string
          id: string
          jornada_type: string
          member_id: string
          shift_date: string
          work_site_id: string | null
        }
        Insert: {
          assigned_by: string
          company_id: string
          created_at?: string
          id?: string
          jornada_type: string
          member_id: string
          shift_date: string
          work_site_id?: string | null
        }
        Update: {
          assigned_by?: string
          company_id?: string
          created_at?: string
          id?: string
          jornada_type?: string
          member_id?: string
          shift_date?: string
          work_site_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "assigned_shifts_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assigned_shifts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assigned_shifts_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assigned_shifts_work_site_id_fkey"
            columns: ["work_site_id"]
            isOneToOne: false
            referencedRelation: "work_sites"
            referencedColumns: ["id"]
          },
        ]
      }
      checkin_events: {
        Row: {
          checkin_at: string | null
          checkin_latitude: number | null
          checkin_longitude: number | null
          checkin_photo_path: string | null
          checkout_at: string | null
          checkout_latitude: number | null
          checkout_longitude: number | null
          checkout_photo_path: string | null
          company_id: string
          created_at: string
          id: string
          ledger_entry_id: string
          member_id: string
          work_site_id: string | null
        }
        Insert: {
          checkin_at?: string | null
          checkin_latitude?: number | null
          checkin_longitude?: number | null
          checkin_photo_path?: string | null
          checkout_at?: string | null
          checkout_latitude?: number | null
          checkout_longitude?: number | null
          checkout_photo_path?: string | null
          company_id: string
          created_at?: string
          id?: string
          ledger_entry_id: string
          member_id: string
          work_site_id?: string | null
        }
        Update: {
          checkin_at?: string | null
          checkin_latitude?: number | null
          checkin_longitude?: number | null
          checkin_photo_path?: string | null
          checkout_at?: string | null
          checkout_latitude?: number | null
          checkout_longitude?: number | null
          checkout_photo_path?: string | null
          company_id?: string
          created_at?: string
          id?: string
          ledger_entry_id?: string
          member_id?: string
          work_site_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "checkin_events_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "checkin_events_ledger_entry_id_fkey"
            columns: ["ledger_entry_id"]
            isOneToOne: true
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "checkin_events_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "checkin_events_work_site_id_fkey"
            columns: ["work_site_id"]
            isOneToOne: false
            referencedRelation: "work_sites"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          business_need: string[]
          city: string | null
          compliance_pending: boolean
          country: string
          created_at: string
          id: string
          industry_category: string
          industry_other_note: string | null
          jurisdiction: string | null
          name: string
          plan: string
          referral_code: string
          referred_by_code: string | null
          region: string
          supervision_contracted: boolean
          supervision_contracted_at: string | null
        }
        Insert: {
          business_need?: string[]
          city?: string | null
          compliance_pending?: boolean
          country: string
          created_at?: string
          id?: string
          industry_category: string
          industry_other_note?: string | null
          jurisdiction?: string | null
          name: string
          plan?: string
          referral_code: string
          referred_by_code?: string | null
          region: string
          supervision_contracted?: boolean
          supervision_contracted_at?: string | null
        }
        Update: {
          business_need?: string[]
          city?: string | null
          compliance_pending?: boolean
          country?: string
          created_at?: string
          id?: string
          industry_category?: string
          industry_other_note?: string | null
          jurisdiction?: string | null
          name?: string
          plan?: string
          referral_code?: string
          referred_by_code?: string | null
          region?: string
          supervision_contracted?: boolean
          supervision_contracted_at?: string | null
        }
        Relationships: []
      }
      company_members: {
        Row: {
          checkin_blocked: boolean
          checkin_blocked_at: string | null
          company_id: string
          created_at: string
          full_day_value: number | null
          half_day_value: number | null
          id: string
          is_billing_owner: boolean
          pay_period: string
          profile_id: string
          profile_type: string
          role: string
          status: string
        }
        Insert: {
          checkin_blocked?: boolean
          checkin_blocked_at?: string | null
          company_id: string
          created_at?: string
          full_day_value?: number | null
          half_day_value?: number | null
          id?: string
          is_billing_owner?: boolean
          pay_period?: string
          profile_id: string
          profile_type: string
          role: string
          status?: string
        }
        Update: {
          checkin_blocked?: boolean
          checkin_blocked_at?: string | null
          company_id?: string
          created_at?: string
          full_day_value?: number | null
          half_day_value?: number | null
          id?: string
          is_billing_owner?: boolean
          pay_period?: string
          profile_id?: string
          profile_type?: string
          role?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "company_members_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "company_members_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      compliance_alerts: {
        Row: {
          acknowledged: boolean
          company_id: string
          created_at: string
          id: string
          implied_hourly_rate: number | null
          ledger_entry_id: string | null
          member_id: string
          rule_id: string
          shown_at: string | null
          shown_to: string | null
        }
        Insert: {
          acknowledged?: boolean
          company_id: string
          created_at?: string
          id?: string
          implied_hourly_rate?: number | null
          ledger_entry_id?: string | null
          member_id: string
          rule_id: string
          shown_at?: string | null
          shown_to?: string | null
        }
        Update: {
          acknowledged?: boolean
          company_id?: string
          created_at?: string
          id?: string
          implied_hourly_rate?: number | null
          ledger_entry_id?: string | null
          member_id?: string
          rule_id?: string
          shown_at?: string | null
          shown_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "compliance_alerts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "compliance_alerts_ledger_entry_id_fkey"
            columns: ["ledger_entry_id"]
            isOneToOne: false
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "compliance_alerts_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "compliance_alerts_rule_id_fkey"
            columns: ["rule_id"]
            isOneToOne: false
            referencedRelation: "compliance_rules"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "compliance_alerts_shown_to_fkey"
            columns: ["shown_to"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
        ]
      }
      compliance_rules: {
        Row: {
          base_value: number
          created_at: string
          currency: string
          effective_from: string
          id: string
          jurisdiction: string
          rule_type: string
          source_url: string | null
          surcharge_percentage: number | null
          threshold_hours_week: number | null
        }
        Insert: {
          base_value: number
          created_at?: string
          currency: string
          effective_from: string
          id?: string
          jurisdiction: string
          rule_type: string
          source_url?: string | null
          surcharge_percentage?: number | null
          threshold_hours_week?: number | null
        }
        Update: {
          base_value?: number
          created_at?: string
          currency?: string
          effective_from?: string
          id?: string
          jurisdiction?: string
          rule_type?: string
          source_url?: string | null
          surcharge_percentage?: number | null
          threshold_hours_week?: number | null
        }
        Relationships: []
      }
      ledger_entries: {
        Row: {
          amount: number
          company_id: string | null
          confirmed_at: string | null
          confirmed_by: string | null
          created_at: string
          hours_reported: number | null
          id: string
          metadata: Json
          origin_member_id: string | null
          origin_profile_id: string
          period_ref: string
          rejection_reason: string | null
          related_entry_id: string | null
          scope: string
          status: string
          type: string
          work_site_id: string | null
        }
        Insert: {
          amount: number
          company_id?: string | null
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          hours_reported?: number | null
          id?: string
          metadata?: Json
          origin_member_id?: string | null
          origin_profile_id: string
          period_ref: string
          rejection_reason?: string | null
          related_entry_id?: string | null
          scope: string
          status?: string
          type: string
          work_site_id?: string | null
        }
        Update: {
          amount?: number
          company_id?: string | null
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          hours_reported?: number | null
          id?: string
          metadata?: Json
          origin_member_id?: string | null
          origin_profile_id?: string
          period_ref?: string
          rejection_reason?: string | null
          related_entry_id?: string | null
          scope?: string
          status?: string
          type?: string
          work_site_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_origin_member_id_fkey"
            columns: ["origin_member_id"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_origin_profile_id_fkey"
            columns: ["origin_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_related_entry_id_fkey"
            columns: ["related_entry_id"]
            isOneToOne: false
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_work_site_id_fkey"
            columns: ["work_site_id"]
            isOneToOne: false
            referencedRelation: "work_sites"
            referencedColumns: ["id"]
          },
        ]
      }
      modification_requests: {
        Row: {
          approved_by: string | null
          created_at: string
          id: string
          ledger_entry_id: string
          new_values: Json
          original_snapshot: Json
          reason: string | null
          requested_by: string
          status: string
          within_72h_window: boolean
        }
        Insert: {
          approved_by?: string | null
          created_at?: string
          id?: string
          ledger_entry_id: string
          new_values: Json
          original_snapshot: Json
          reason?: string | null
          requested_by: string
          status?: string
          within_72h_window: boolean
        }
        Update: {
          approved_by?: string | null
          created_at?: string
          id?: string
          ledger_entry_id?: string
          new_values?: Json
          original_snapshot?: Json
          reason?: string | null
          requested_by?: string
          status?: string
          within_72h_window?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "modification_requests_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "modification_requests_ledger_entry_id_fkey"
            columns: ["ledger_entry_id"]
            isOneToOne: false
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "modification_requests_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          auth_user_id: string | null
          created_at: string
          email: string | null
          full_name: string
          id: string
          platform_role: string | null
        }
        Insert: {
          auth_user_id?: string | null
          created_at?: string
          email?: string | null
          full_name: string
          id?: string
          platform_role?: string | null
        }
        Update: {
          auth_user_id?: string | null
          created_at?: string
          email?: string | null
          full_name?: string
          id?: string
          platform_role?: string | null
        }
        Relationships: []
      }
      work_sites: {
        Row: {
          address: string
          company_id: string
          created_at: string
          id: string
          latitude: number | null
          longitude: number | null
          name: string
          status: string
        }
        Insert: {
          address: string
          company_id: string
          created_at?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          name: string
          status?: string
        }
        Update: {
          address?: string
          company_id?: string
          created_at?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          name?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "work_sites_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      v_member_balance: {
        Row: {
          company_id: string | null
          confirmed_balance: number | null
          member_id: string | null
          pending_balance: number | null
          period_ref: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_origin_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "company_members"
            referencedColumns: ["id"]
          },
        ]
      }
      v_company_overview: {
        Row: {
          active_members: number | null
          active_work_sites: number | null
          company_id: string | null
          compliance_pending: boolean | null
          created_at: string | null
          jurisdiction: string | null
          name: string | null
          owners: number | null
          pending_entries: number | null
          plan: string | null
          supervision_contracted: boolean | null
          week_income: number | null
        }
        Relationships: []
      }
      v_work_site_totals: {
        Row: {
          company_id: string | null
          income: number | null
          labour_cost: number | null
          period_ref: string | null
          work_site_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_work_site_id_fkey"
            columns: ["work_site_id"]
            isOneToOne: false
            referencedRelation: "work_sites"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      bootstrap_company: {
        Args: {
          p_business_need: string[]
          p_city: string
          p_company_name: string
          p_country: string
          p_industry_category: string
          p_industry_other_note: string
          p_owner_full_name: string
          p_referred_by_code: string
          p_region: string
        }
        Returns: string
      }
      ensure_profile: { Args: never, Returns: string }
      invite_team_member: {
        Args: {
          p_company_id: string
          p_email: string
          p_full_day_value?: number
          p_full_name: string
          p_half_day_value?: number
          p_pay_period?: string
          p_role: string
        }
        Returns: string
      }
      set_admin_work_sites: {
        Args: { p_member_id: string, p_work_site_ids: string[] }
        Returns: number
      }
      set_supervision_contracted: {
        Args: { p_company_id: string, p_contracted: boolean }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
