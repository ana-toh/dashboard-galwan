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
    PostgrestVersion: "13.0.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      broker_availability: {
        Row: {
          available_date: string | null
          broker_id: string | null
          created_at: string | null
          end_time: string | null
          id: string
          is_available: boolean | null
          queue_position: number | null
          start_time: string | null
          updated_at: string | null
        }
        Insert: {
          available_date?: string | null
          broker_id?: string | null
          created_at?: string | null
          end_time?: string | null
          id?: string
          is_available?: boolean | null
          queue_position?: number | null
          start_time?: string | null
          updated_at?: string | null
        }
        Update: {
          available_date?: string | null
          broker_id?: string | null
          created_at?: string | null
          end_time?: string | null
          id?: string
          is_available?: boolean | null
          queue_position?: number | null
          start_time?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "broker_availability_broker_id_fkey"
            columns: ["broker_id"]
            isOneToOne: false
            referencedRelation: "brokers"
            referencedColumns: ["id"]
          },
        ]
      }
      brokers: {
        Row: {
          calendar_color: string | null
          created_at: string | null
          email: string | null
          first_name: string | null
          id: string
          is_active: boolean | null
          last_name: string | null
          updated_at: string | null
          whatsapp: string | null
        }
        Insert: {
          calendar_color?: string | null
          created_at?: string | null
          email?: string | null
          first_name?: string | null
          id?: string
          is_active?: boolean | null
          last_name?: string | null
          updated_at?: string | null
          whatsapp?: string | null
        }
        Update: {
          calendar_color?: string | null
          created_at?: string | null
          email?: string | null
          first_name?: string | null
          id?: string
          is_active?: boolean | null
          last_name?: string | null
          updated_at?: string | null
          whatsapp?: string | null
        }
        Relationships: []
      }
      hallucination_alerts: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          number_incorrect_messages: number | null
          severity: Database["public"]["Enums"]["alert_severity"] | null
          status: Database["public"]["Enums"]["alert_status"] | null
          title: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          number_incorrect_messages?: number | null
          severity?: Database["public"]["Enums"]["alert_severity"] | null
          status?: Database["public"]["Enums"]["alert_status"] | null
          title?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          number_incorrect_messages?: number | null
          severity?: Database["public"]["Enums"]["alert_severity"] | null
          status?: Database["public"]["Enums"]["alert_status"] | null
          title?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      improvement_suggestions: {
        Row: {
          category: string | null
          created_at: string | null
          id: string
          is_resolved: boolean | null
          problem_description: string | null
          reason: string | null
          solution: string | null
        }
        Insert: {
          category?: string | null
          created_at?: string | null
          id?: string
          is_resolved?: boolean | null
          problem_description?: string | null
          reason?: string | null
          solution?: string | null
        }
        Update: {
          category?: string | null
          created_at?: string | null
          id?: string
          is_resolved?: boolean | null
          problem_description?: string | null
          reason?: string | null
          solution?: string | null
        }
        Relationships: []
      }
      leads: {
        Row: {
          agreed_terms: boolean | null
          created_at: string
          id: string
          initial_message: boolean
          is_active: boolean | null
          name: string
          request_notes: string | null
          updated_at: string | null
          whatsapp: string | null
        }
        Insert: {
          agreed_terms?: boolean | null
          created_at?: string
          id?: string
          initial_message?: boolean
          is_active?: boolean | null
          name: string
          request_notes?: string | null
          updated_at?: string | null
          whatsapp?: string | null
        }
        Update: {
          agreed_terms?: boolean | null
          created_at?: string
          id?: string
          initial_message?: boolean
          is_active?: boolean | null
          name?: string
          request_notes?: string | null
          updated_at?: string | null
          whatsapp?: string | null
        }
        Relationships: []
      }
      logs: {
        Row: {
          action: Database["public"]["Enums"]["log_action"]
          created_at: string
          description: string
          feature: Database["public"]["Enums"]["log_feature"]
          id: string
          user_email: string
        }
        Insert: {
          action: Database["public"]["Enums"]["log_action"]
          created_at?: string
          description: string
          feature: Database["public"]["Enums"]["log_feature"]
          id?: string
          user_email: string
        }
        Update: {
          action?: Database["public"]["Enums"]["log_action"]
          created_at?: string
          description?: string
          feature?: Database["public"]["Enums"]["log_feature"]
          id?: string
          user_email?: string
        }
        Relationships: []
      }
      n8n_assistant_dash_history: {
        Row: {
          id: number
          message: Json
          session_id: string
        }
        Insert: {
          id?: number
          message: Json
          session_id: string
        }
        Update: {
          id?: number
          message?: Json
          session_id?: string
        }
        Relationships: []
      }
      n8n_history: {
        Row: {
          created_at: string
          id: number
          message: Json
          session_id: string
        }
        Insert: {
          created_at?: string
          id?: number
          message: Json
          session_id: string
        }
        Update: {
          created_at?: string
          id?: number
          message?: Json
          session_id?: string
        }
        Relationships: []
      }
      project_images: {
        Row: {
          created_at: string
          id: string
          image_url: string
          index_order: number
          project_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url: string
          index_order?: number
          project_id: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string
          index_order?: number
          project_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_images_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          city: string | null
          content: string | null
          created_at: string | null
          delivery_date: string | null
          description: string | null
          embedding: string | null
          id: string
          launch_date: string | null
          metadata: Json | null
          name: string | null
          neighborhood: string | null
          project_images_urls: string[] | null
          project_website: string | null
          reference_points: string | null
          state: string | null
          status: Database["public"]["Enums"]["project_status"] | null
          updated_at: string | null
        }
        Insert: {
          city?: string | null
          content?: string | null
          created_at?: string | null
          delivery_date?: string | null
          description?: string | null
          embedding?: string | null
          id?: string
          launch_date?: string | null
          metadata?: Json | null
          name?: string | null
          neighborhood?: string | null
          project_images_urls?: string[] | null
          project_website?: string | null
          reference_points?: string | null
          state?: string | null
          status?: Database["public"]["Enums"]["project_status"] | null
          updated_at?: string | null
        }
        Update: {
          city?: string | null
          content?: string | null
          created_at?: string | null
          delivery_date?: string | null
          description?: string | null
          embedding?: string | null
          id?: string
          launch_date?: string | null
          metadata?: Json | null
          name?: string | null
          neighborhood?: string | null
          project_images_urls?: string[] | null
          project_website?: string | null
          reference_points?: string | null
          state?: string | null
          status?: Database["public"]["Enums"]["project_status"] | null
          updated_at?: string | null
        }
        Relationships: []
      }
      prompt: {
        Row: {
          created_at: string | null
          emojis: string | null
          full_prompt: string | null
          id: string
          identity: string
          qualification_methodology: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          emojis?: string | null
          full_prompt?: string | null
          id?: string
          identity: string
          qualification_methodology: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          emojis?: string | null
          full_prompt?: string | null
          id?: string
          identity?: string
          qualification_methodology?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      users: {
        Row: {
          created_at: string
          email: string | null
          id: string
          is_active: boolean
          permitted_areas: string[]
          role: Database["public"]["Enums"]["user_role"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          id: string
          is_active?: boolean
          permitted_areas?: string[]
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string | null
          id?: string
          is_active?: boolean
          permitted_areas?: string[]
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      can_access_area: { Args: { area: string }; Returns: boolean }
      get_hallucination_rate: {
        Args: { p_end?: string; p_start?: string }
        Returns: {
          rate: number
          total_incorrect: number
          total_messages: number
        }[]
      }
      get_next_corretor: { Args: never; Returns: Json }
      is_active_user: { Args: { uid: string }; Returns: boolean }
      is_admin:
        | { Args: never; Returns: boolean }
        | { Args: { uid: string }; Returns: boolean }
      match_documents: {
        Args: { filter?: Json; match_count?: number; query_embedding: string }
        Returns: {
          content: string
          id: string
          metadata: Json
          similarity: number
        }[]
      }
      search_projects_by_embedding: {
        Args: {
          match_count?: number
          match_threshold?: number
          query_embedding: string
        }
        Returns: {
          bairro: string
          criado_em: string
          data_entrega: string
          data_lancamento: string
          descricao: string
          email_responsavel: string
          id: string
          nome: string
          pdf_url: string
          similarity_score: number
          status: Database["public"]["Enums"]["project_status"]
        }[]
      }
      user_has_area: { Args: { area: string; uid: string }; Returns: boolean }
    }
    Enums: {
      alert_severity: "Alto" | "Médio" | "Baixo"
      alert_status:
        | "resolvido"
        | "em andamento"
        | "em testes"
        | "pendente"
        | "cancelado"
      log_action: "CREATE" | "UPDATE" | "DELETE"
      log_feature:
        | "prompts"
        | "projetos"
        | "corretores"
        | "chat"
        | "leads"
        | "metricas"
      project_status: "Ativo" | "Inativo" | "Disponível em breve"
      user_role: "admin" | "colaborador"
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
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      alert_severity: ["Alto", "Médio", "Baixo"],
      alert_status: [
        "resolvido",
        "em andamento",
        "em testes",
        "pendente",
        "cancelado",
      ],
      log_action: ["CREATE", "UPDATE", "DELETE"],
      log_feature: [
        "prompts",
        "projetos",
        "corretores",
        "chat",
        "leads",
        "metricas",
      ],
      project_status: ["Ativo", "Inativo", "Disponível em breve"],
      user_role: ["admin", "colaborador"],
    },
  },
} as const
