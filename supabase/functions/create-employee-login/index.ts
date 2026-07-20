import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

function randomPassword() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  let out = "";
  for (let i = 0; i < 10; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

// Called from the app's admin "Employees" page after saving an employee
// with no auth_user yet. Creates their Supabase Auth login (using the
// employee's stored business email) and links it back to their row.
// Runs with the service-role key server-side — the anon/publishable key
// used by the browser can never create Auth users on its own.
export default {
  fetch: withSupabase({ auth: ["publishable"] }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405 });
    }

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) {
      return Response.json({ error: "Missing auth token" }, { status: 401 });
    }

    const { data: callerData, error: callerErr } = await ctx.supabaseAdmin.auth.getUser(jwt);
    if (callerErr || !callerData?.user) {
      return Response.json({ error: "Invalid session" }, { status: 401 });
    }

    const { data: callerEmp } = await ctx.supabaseAdmin
      .from("employees")
      .select("is_admin")
      .eq("auth_user", callerData.user.id)
      .maybeSingle();

    if (!callerEmp?.is_admin) {
      return Response.json({ error: "Admin access required" }, { status: 403 });
    }

    const { employeeId } = await req.json();
    if (!employeeId) {
      return Response.json({ error: "employeeId is required" }, { status: 400 });
    }

    const { data: emp, error: empErr } = await ctx.supabaseAdmin
      .from("employees")
      .select("id, email, auth_user")
      .eq("id", employeeId)
      .maybeSingle();

    if (empErr || !emp) {
      return Response.json({ error: "Employee not found" }, { status: 404 });
    }
    if (!emp.email) {
      return Response.json({ error: "This employee has no email on file" }, { status: 400 });
    }
    if (emp.auth_user) {
      return Response.json({ error: "This employee already has a login" }, { status: 409 });
    }

    const password = randomPassword();

    const { data: created, error: createErr } = await ctx.supabaseAdmin.auth.admin.createUser({
      email: emp.email,
      password,
      email_confirm: true,
    });

    if (createErr || !created?.user) {
      return Response.json({ error: createErr?.message || "Could not create login" }, { status: 500 });
    }

    const { error: linkErr } = await ctx.supabaseAdmin
      .from("employees")
      .update({ auth_user: created.user.id })
      .eq("id", employeeId);

    if (linkErr) {
      return Response.json({ error: linkErr.message }, { status: 500 });
    }

    return Response.json({ email: emp.email, password });
  }),
};
