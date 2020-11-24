with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Characters.Handling; use Ada.Characters.Handling;

with SPDX.Licenses;
with SPDX.Exceptions;

package body SPDX is

   function Token_Str (This : Expression; Loc : Location) return String;

   function Is_Custom_Id (Str : String) return Boolean;
   procedure Parse_License (This : in out Expression);
   procedure Parse_Compound_Expression (This : in out Expression);
   procedure Parse_Simple_Expression (This : in out Expression);
   procedure Parse_Exception (This : in out Expression);

   ---------------
   -- Token_Str --
   ---------------

   function Token_Str (This : Expression; Loc : Location) return String is
   begin
      if Loc.From not in This.Str'Range
        or else
          Loc.To not in This.Str'Range
      then
         return "";
      else
         return This.Str (Loc.From .. Loc.To);
      end if;
   end Token_Str;

   ------------------
   -- Is_Custom_Id --
   ------------------

   function Is_Custom_Id (Str : String) return Boolean is
      Lower  : constant String := To_Lower (Str);
      Prefix : constant String := "custom-";
   begin
      return Lower'Length > Prefix'Length
        and then
          Lower (Lower'First .. Lower'First + Prefix'Length - 1) = Prefix;
   end Is_Custom_Id;

   -------------------
   -- Parse_License --
   -------------------

   procedure Parse_License (This : in out Expression) is
   begin
      Parse_Compound_Expression (This);

      if This.Error /= None then
         return;
      end if;

      if not This.Tokens.Is_Empty then
         This.Error := Unexpected_Token;
         This.Err_Loc := This.Tokens.First_Element.Loc;
      end if;
   end Parse_License;

   -------------------------------
   -- Parse_Compound_Expression --
   -------------------------------

   procedure Parse_Compound_Expression (This : in out Expression) is
   begin
      --  compound = ( compound )
      --             | simple
      --             | simple AND compound
      --             | simple OR compound

      if This.Tokens.Is_Empty then
         This.Error := Empty_Expression;
         This.Err_Loc := (This.Str'Last, This.Str'Last);
         return;
      end if;

      case This.Tokens.First_Element.Kind is

      when Paren_Open =>

         This.Tokens.Delete_First;

         Parse_Compound_Expression (This);

         if This.Error /= None then
            return;
         end if;

         if This.Tokens.Is_Empty then
            This.Error := Paren_Close_Expected;
            This.Err_Loc := (This.Str'Last, This.Str'Last);
            return;
         end if;

         if This.Tokens.First_Element.Kind /= Paren_Close then
            This.Error := Paren_Close_Expected;
            This.Err_Loc := This.Tokens.First_Element.Loc;
            return;
         end if;

         --  Delete the Paren_Close
         This.Tokens.Delete_First;

      when Id_Str =>
         Parse_Simple_Expression (This);

         if This.Error /= None then
            return;
         end if;

      when others =>
         This.Error := Unexpected_Token;
         This.Err_Loc := This.Tokens.First_Element.Loc;
         return;
      end case;

      if This.Tokens.Is_Empty then
         --  End of expression
         return;
      end if;

      if This.Tokens.First_Element.Kind in Op_And | Op_Or then
         --  Just skip operator as we do not build the AST
         This.Tokens.Delete_First;

         Parse_Compound_Expression (This);
      end if;
   end Parse_Compound_Expression;

   -----------------------------
   -- Parse_Simple_Expression --
   -----------------------------

   procedure Parse_Simple_Expression (This : in out Expression) is
   begin
      --  simple =   id
      --           | id+
      --           | id exception
      --           | id+ exception

      if This.Tokens.Is_Empty then
         This.Error := License_Id_Expected;
         This.Err_Loc := (This.Str'Last, This.Str'Last);
         return;
      end if;

      if This.Tokens.First_Element.Kind /= Id_Str then
         This.Error := License_Id_Expected;
         This.Err_Loc := This.Tokens.First_Element.Loc;
         return;
      end if;

      declare
         License_Id : constant String :=
           Token_Str (This, This.Tokens.First_Element.Loc);
      begin

         if This.Allow_Custom and then Is_Custom_Id (License_Id) then
            This.Has_Custom_Id := True;
         elsif not SPDX.Licenses.Valid_Id (License_Id) then
            This.Error := Invalid_License_Id;
            This.Err_Loc := This.Tokens.First_Element.Loc;
         end if;

         This.Tokens.Delete_First;

         if This.Tokens.Is_Empty then
            return;
         end if;

         --  + operator
         if This.Tokens.First_Element.Kind = Op_Or_Later then
            This.Tokens.Delete_First;
         end if;

         if This.Tokens.Is_Empty then
            return;
         end if;

         Parse_Exception (This);
      end;

   end Parse_Simple_Expression;

   ---------------------
   -- Parse_Exception --
   ---------------------

   procedure Parse_Exception (This : in out Expression) is
   begin
      --  exception =   <nothing>
      --              | WITH id

      if This.Tokens.First_Element.Kind = Op_With then

         This.Tokens.Delete_First;

         if This.Tokens.Is_Empty then
            This.Error := Exception_Id_Expected;
            This.Err_Loc := (This.Str'Last, This.Str'Last);
            return;
         end if;

         if This.Tokens.First_Element.Kind /= Id_Str then
            This.Error := Exception_Id_Expected;
            This.Err_Loc := This.Tokens.First_Element.Loc;
            return;
         end if;

         declare
            Exception_Id : constant String :=
              Token_Str (This, This.Tokens.First_Element.Loc);
         begin
            if not SPDX.Exceptions.Valid_Id (Exception_Id) then
               This.Error := Invalid_Exception_Id;
               This.Err_Loc := This.Tokens.First_Element.Loc;
            end if;
               This.Tokens.Delete_First;
         end;
      end if;
   end Parse_Exception;

   -----------
   -- Parse --
   -----------

   function Parse (Str          : String;
                   Allow_Custom : Boolean := False)
                   return Expression
   is
      Exp : Expression (Str'Length);
   begin

      Exp.Str := Str;
      Exp.Allow_Custom := Allow_Custom;

      Tokenize (Exp);

      if Exp.Error /= None then
         return Exp;
      end if;

      Parse_License (Exp);

      return Exp;
   end Parse;

   -----------
   -- Error --
   -----------

   function Error (This : Expression) return String is

      function Img (N : Natural) return String;
      function Img (Loc : Location) return String;

      ---------
      -- Img --
      ---------

      function Img (N : Natural) return String
      is (Ada.Strings.Fixed.Trim (N'Img, Ada.Strings.Left));

      ---------
      -- Img --
      ---------

      function Img (Loc : Location) return String
      is ((Img (Loc.From) & ":" & Img (Loc.To)));

   begin
      case This.Error is
         when None =>
            return "";

         when Or_Later_Misplaced =>
            return "+ operator must follow and indentifier without " &
              "whitespace (" & Img (This.Err_Loc) & ")";

         when Invalid_Char =>
            return "Invalid character at " & Img (This.Err_Loc.From);

         when Operator_Lowcase =>
            return "Operator must be uppercase at (" & Img (This.Err_Loc) & ")";

         when Unexpected_Token =>
            return "Unexpected token at (" & Img (This.Err_Loc) & ")";

         when Paren_Close_Expected =>
            return "Missing closing parentheses ')' at (" &
              Img (This.Err_Loc) & ")";

         when License_Id_Expected =>
            return "License id expected at (" & Img (This.Err_Loc) & ")";

         when Invalid_License_Id =>
            return "Invalid license ID: '" &
              Token_Str (This, This.Err_Loc) & "' (" & Img (This.Err_Loc) & ")";

         when Exception_Id_Expected =>
            return "License exception id expected at (" &
              Img (This.Err_Loc) & ")";

         when Invalid_Exception_Id =>
            return "Invalid license exception ID: '" &
              Token_Str (This, This.Err_Loc) &
              "' (" & Img (This.Err_Loc) & ")";

         when Empty_Expression =>
            return "Empty license expression at (" & Img (This.Err_Loc) & ")";

      end case;
   end Error;

   -----------
   -- Valid --
   -----------

   function Valid (This : Expression) return Boolean is
   begin
      return This.Error = None;
   end Valid;

   ---------
   -- Img --
   ---------

   function Img (This : Expression) return String is
   begin
      return This.Str;
   end Img;

   ----------------
   -- Has_Custom --
   ----------------

   function Has_Custom (This : Expression) return Boolean
   is (This.Has_Custom_Id);

   --------------
   -- Tokenize --
   --------------

   procedure Tokenize (This : in out Expression) is

      Tokens : Token_Vector.Vector renames This.Tokens;
      Str : String renames This.Str;

      Index : Natural := Str'First;

   begin
      while Index in Str'Range loop

         if Str (Index) in Whitespace_Characters then
            Index := Index + 1; -- Skip whitespace

         elsif Str (Index) = '(' then
            Tokens.Append ((Paren_Open, (Index, Index)));
            Index := Index + 1;

         elsif Str (Index) = ')' then
            Tokens.Append ((Paren_Close, (Index, Index)));
            Index := Index + 1;

         elsif Str (Index) = '+' then
            This.Error := Or_Later_Misplaced;
            This.Err_Loc := (Index, Index);
            return;

         elsif Str (Index) in Id_Characters then

            --  Operator or identifier

            declare
               From : constant Natural := Index;
            begin
               while Index in Str'Range
                 and then Str (Index) in Id_Characters | '+'
               loop
                  Index := Index + 1;
               end loop;

               declare
                  To     : constant Natural := Index - 1;
                  Substr : constant String := Str (From .. To);
               begin
                  if Substr = "WITH" then
                     Tokens.Append ((Op_With, (From, To)));

                  elsif Substr = "OR" then
                     Tokens.Append ((Op_Or, (From, To)));

                  elsif Substr = "AND" then
                     Tokens.Append ((Op_And, (From, To)));

                  elsif To_Lower (Substr) = "with"
                    or else To_Lower (Substr) = "or"
                    or else To_Lower (Substr) = "and"
                  then
                     This.Error := Operator_Lowcase;
                     This.Err_Loc := (From, To);
                     return;

                  else
                     if Str (To) = '+' then
                        --  + operator can be found after and id (without
                        --  whitespace).
                        Tokens.Append ((Id_Str, (From, To - 1)));
                        Tokens.Append ((Op_Or_Later, (To, To)));
                     else
                        Tokens.Append ((Id_Str, (From, To)));
                     end if;
                  end if;
               end;
            end;

         else
            This.Error := Invalid_Char;
            This.Err_Loc := (Index, Index);
            return;

         end if;
      end loop;
   end Tokenize;
end SPDX;
