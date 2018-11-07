From Mtac2 Require Import Base MTele Mtac2.
Import Sorts.S.
Import M.notations.
Import M.M.

Module V1.

  Definition lift (A : Type) (m : MTele) : M Type :=
    (mfix1 f (A : Type) : M Type :=
      mmatch A in Type as A' return M Type with
      | [? T] (M T):Type => ret (MTele_ConstT T m)
      | [? T1 T2] T1 -> T2 => t1 <- f T1;
                              t2 <- f T2;
                              ret (t1 -> t2)
      | [? T (V : forall x : T, Type)] (forall t : T, V t) => \nu_f for A as t : T,
                                                                v1 <- f (V t);
                                                                abs_prod_type t v1
      | _ => ret (A)
      end) A.

  Definition lift' {A} (m : MTele) (a : A) := lift A m.

  Goal MTele -> Type.
  intros m.
  mrun (lift (M nat) m).
  Show Proof. Abort.

End V1.

Module V2.
  
  Local Notation MFA T := (MTele_val (MTele_C SType SProp M T)).

  Definition repl {m : MTele} (A : MTele_Ty m) := MTele_val A.
  
  Definition hold {T : Type} (V : T -> Type) {m : MTele} (A : SType) : T -> Type := V .
  (* Set Printing Universes. *)
  Definition lift (A : Type) (m : MTele) : M Type :=
    (mfix1 f (A : Type) : M Type :=
      M.print_term A;;
      mmatch A in Type as A' return M Type with
      | [? m A] @repl m A =>
          ret (MTele_val A)
      | [? A] (M (@repl m A)):Type =>
          ret ((MFA A):Type)
      | [? A] (M A):Type =>
          ret (MTele_ConstT A m)
      | [? T1 T2] T1 -> T2 =>
          M.print "BRANCH implication";;
          t1 <- f T1;
          t2 <- f T2;
          ret (t1 -> t2)
      | [? (V : forall X : Type, Type)] (forall X : Type, V X) =>
          M.print "BRANCH forall1";;
          \nu_f for A as X : MTele_Ty m,
              v <- f (V (@repl m X));
              abs_prod_type X v
      | [? (V : forall X : Type, Prop)] (forall X : Type, V X):Type =>
          M.print "BRANCH forall1_prop";;
          \nu_f for A as X : MTele_Ty m,
              let x := reduce (RedOneStep [rl:RedBeta]) (V (@repl m X)) in
              v <- f (x);
              abs_prod_type X v
      | [? T (V : forall x : T, Type)] (forall t : T, V t) =>
          M.print "BRANCH forall2";;
          \nu_f for A as t : T,
              v1 <- f (V t);
              abs_prod_type t v1
      | [? m V A] (V (@repl m A)) =>
          M.failwith "Unused repl"
      | _ =>
          ret (A)
      end) A.

  Definition lift' {A} (a : A) (m : MTele) := lift A m.

  Goal MTele -> Type.
  intros m.
  mrun (lift' (@bind) m).
  Show Proof. Abort.

End V2.

Module V3.
  
  Local Notation MFA T := (MTele_val (MTele_C SType SProp M T)).

  Polymorphic Definition repl {m : MTele} {s : Sort} (A : MTele_Sort s m) := MTele_val A.
  
  Notation "'[withP' now_ty , now_val '=>' t ]" :=
    (MTele_In (SProp) (fun now_ty now_val => t))
  (at level 0, format "[withP now_ty , now_val => t ]").

  Polymorphic Program Definition lift_neg' (A : Type) (m : MTele)
  (now_ty : forall (s : Sort), MTele_Sort s m -> s)
  (_ : forall (s: Sort) (T : MTele_Sort s m), MTele_val T -> now_ty s T) : M Type :=
      (mfix1 f (A : Type) :
      M Type :=
          mmatch A in Type as A' return
          M Type with
          | [? A] @repl m SType A =>
              ret (now_ty SType A)
          | [? (A : MTele_Sort SType m)] (M (@repl m SType A)):Type =>
              ret (let A' := now_ty SType A in
                  (M A'):Type)
          | [? A B] A -> B =>
              A' <- f A;
              B' <- f B;
              ret (A' -> B')
          | _ => ret (A)
          end) A.

  Polymorphic Definition lift_neg (A : Type) (m : MTele) : M Type :=
      \nu now_ty : forall (s : Sort), MTele_Sort s m -> s,
        \nu now_val : _,
          F <- lift_neg' A m now_ty now_val;
          F <- abs_fun (A := forall (s: Sort) (T : MTele_Sort s m), MTele_val T -> now_ty s T) (P := fun now_val => Type) now_val F;
          F <- abs_fun (A := forall (s : Sort), MTele_Sort s m -> s) (P := fun now_ty => (forall (s: Sort) (T : MTele_Sort s m), MTele_val T -> now_ty s T) -> Type) now_ty F;
          ret (MTele_val (@MTele_In SType m F)). 

  (* Set Printing Universes. *)
  Polymorphic Definition lift (A : Type) (m : MTele) : M Type :=
    (mfix1 f (A : Type) : M Type :=
      M.print_term A;;
      mmatch A in Type as A' return M Type with
      | [? m A] @repl m SType A =>
          M.print "Case: repl A";;
          ret (MTele_val A)
      | [? A] (M (@repl m SType A)):Type =>
          M.print "Case: M (repl A)";;
          ret ((MFA A):Type)
      | [? A] (M A):Type =>
          M.print "Case: M A";;
          ret (MTele_ConstT A m)
      | [? A B] A -> B =>
          M.print "Case: implication";;
          A' <- lift_neg A m;
          B' <- f B;
          ret (A' -> B')
      | [? (V : forall X : Type, Type)] (forall X : Type, V X) =>
          M.print "Case: forall1 type";;
          \nu_f for A as X : MTele_Ty m,
              v <- f (V (@repl m SType X));
              abs_prod_type X v
      | [? (V : forall X : Type, Prop)] (forall X : Type, V X):Type =>
          M.print "Case: forall1 prop";;
          \nu_f for A as X : MTele_Ty m,
              (* Trying to fix fix1 *)
              (* A <- f (@repl m SType X); *)
              (* let x := reduce (RedOneStep [rl:RedBeta]) (V A) in *)
              let x := reduce (RedOneStep [rl:RedBeta]) (V (@repl m SType X)) in
              v <- f (x);
              abs_prod_type X v
      | [? T (V : forall x : T, Type)] (forall t : T, V t) =>
          M.print "Case: forall2";;
          \nu_f for A as t : T,
              v1 <- f (V t);
              abs_prod_type t v1
      | [? m V A] (V (@repl m SType A)) =>
          M.failwith "Unused replace"
      | _ =>
          ret (A)
      end) A.

  Polymorphic Definition lift' {A} (a : A) (m : MTele) := lift A m.

  Polymorphic Definition bla : MTele -> Type.
  intros m. Mtac Do Unset_Trace. 
  pose (t := ltac:(mrun (lift' (@ret) mBase))).
  cbv iota zeta beta fix delta [MTele_In] in t.
  mrun (lift' (@ret) m).
  Show Proof. Abort.

End V3.
