with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Exceptions;

with SPDX;

procedure Main is

   Fail_Cnt : Natural := 0;
   Pass_Cnt : Natural := 0;

   procedure Test (Str            : String;
                   Expected_Error : String := "";
                   Allow_Custom   : Boolean := False);

   procedure Test (Str            : String;
                   Expected_Error : String := "";
                   Allow_Custom   : Boolean := False)
   is
   begin
      declare
         Exp : constant SPDX.Expression := SPDX.Parse (Str, Allow_Custom);
         Error : constant String :=
           (if SPDX.Valid (Exp) then "" else SPDX.Error (Exp));
      begin
         if Error /= Expected_Error then
            Put_Line ("FAIL: '" & Str & "'");
            if Expected_Error /= "" then
               Put_Line ("   Expected error: '" & Expected_Error & "'");
               Put_Line ("         but got : '" & Error & "'");
            else
               Put_Line ("   Unexpected error: '" & Error & "'");
            end if;

            Fail_Cnt := Fail_Cnt + 1;

         elsif Expected_Error = ""
             and then
               Allow_Custom
             and then
               not SPDX.Has_Custom (Exp)
         then
            Put_Line ("FAIL: '" & Str & "'");
            Put_Line ("   Has_Custom returned False");
            Fail_Cnt := Fail_Cnt + 1;
         else
            Put_Line ("PASS: '" & Str & "'");
            Pass_Cnt := Pass_Cnt + 1;
         end if;
      end;
   exception
      when E : others =>
         Put_Line ("FAIL: '" & Str & "'");
         Put_Line ("    With exception: '" &
                     Ada.Exceptions.Exception_Information (E) & "'");
         Fail_Cnt := Fail_Cnt + 1;
   end Test;

begin

   --  Test all invalid chars
   for C in Character loop
      if C not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' |
                  '-' | '.' | '(' | ')' | '+' | ' ' | ASCII.HT
      then
         Test ("test" & C, "Invalid character at 5");
      end if;
   end loop;

   Test ("", "Empty license expression at (0:0)");
   Test ("test-3", "Invalid license ID: 'test-3' (1:6)");
   Test ("test-3.0", "Invalid license ID: 'test-3.0' (1:8)");
   Test ("MIT");
   Test ("MIT+");
   Test ("MIT OR MIT");
   Test ("MIT AND MIT");
   Test ("MIT Or MIT", "Operator must be uppercase at (5:6)");
   Test ("MIT anD MIT", "Operator must be uppercase at (5:7)");
   Test ("MIT WITH AND", "License exception id expected at (10:12)");
   Test ("MIT WITH", "License exception id expected at (8:8)");
   Test ("MIT WITH plop", "Invalid license exception ID: 'plop' (10:13)");
   Test ("MIT WITH GPL-3.0-linking-exception");
   Test ("(MIT)");
   Test ("(MIT) AND MIT");
   Test ("(MIT+) AND (MIT)");
   Test ("((MIT) AND (MIT+))");
   Test ("((MIT) AND (MIT+ OR MIT AND MIT AND (MIT WITH GPL-3.0-linking-exception AND MIT)))");

   Test ("MIT +", "+ operator must follow and indentifier without whitespace (5:5)");
   Test ("MIT AND +", "+ operator must follow and indentifier without whitespace (9:9)");
   Test ("MIT+AND", "Invalid license ID: 'MIT+AND' (1:7)");

   Test ("MIT AND", "Empty license expression at (7:7)");
   Test ("MIT OR", "Empty license expression at (6:6)");
   Test ("MIT MIT", "Unexpected token at (5:7)");

   Test ("(MIT", "Missing closing parentheses ')' at (4:4)");
   Test ("MIT)", "Unexpected token at (4:4)");
   Test ("(MIT AND (MIT OR MIT)", "Missing closing parentheses ')' at (21:21)");
   Test ("MIT AND (MIT OR MIT))", "Unexpected token at (21:21)");

   Test ("custom-plop", "Invalid license ID: 'custom-plop' (1:11)", Allow_Custom => False);
   Test ("custom", "Invalid license ID: 'custom' (1:6)", Allow_Custom => True);
   Test ("custom-", "Invalid license ID: 'custom-' (1:7)", Allow_Custom => True);
   Test ("custom-plop", Allow_Custom => True);
   Test ("custom-plop+", Allow_Custom => True);
   Test ("custom-test:test", "Invalid character at 12", Allow_Custom => True);
   Test ("CuStoM-test-1.0.3", Allow_Custom => True);
   Test ("custom-test AND custom-plop", Allow_Custom => True);

   Put_Line ("PASS:" & Pass_Cnt'Img);
   Put_Line ("FAIL:" & Fail_Cnt'Img);

   if Fail_Cnt /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Main;
