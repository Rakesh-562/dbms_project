import { useState, useEffect } from 'react';
import { getAcidAccounts, acidAtomicity, acidConsistency, acidIsolation, acidDurability } from '../api';
import { PageHeader, Card, Btn, Select, FormField, Input, Badge } from '../components/UI';
import { Atom, ShieldCheck, Layers, HardDrive, Play, RotateCcw } from 'lucide-react';

const stepColors = {
  BEGIN: 'blue', COMMIT: 'green', ROLLBACK: 'red', ERROR_ROLLBACK: 'red', ERROR: 'red',
  DEBIT: 'amber', CREDIT: 'green', DEPOSIT: 'green',
  INJECTED_ERROR: 'red', CONSTRAINT_VIOLATED: 'red', FK_ERROR: 'red',
  TXN_A_BEGIN: 'blue', TXN_A_DEBIT: 'amber', TXN_A_COMMIT: 'green',
  TXN_B_BEGIN: 'indigo', TXN_B_READ: 'indigo', TXN_B_READ_AGAIN: 'indigo', TXN_B_COMMIT: 'green',
  READ_BEFORE: 'default', READ_AFTER: 'default', INITIAL: 'default', VERIFY: 'green',
  ATTEMPT: 'amber', AUDIT_LOG: 'blue', DURABILITY_PROVEN: 'green',
};

function LogViewer({ log }) {
  if (!log?.length) return null;
  return (
    <div className="mt-4 space-y-1">
      {log.map((entry, i) => (
        <div key={i} className="flex items-start gap-3 p-2 bg-gray-50 rounded text-sm font-mono">
          <Badge variant={stepColors[entry.step] || 'default'}>{entry.step}</Badge>
          <span className="text-gray-700 flex-1">{entry.detail}</span>
        </div>
      ))}
    </div>
  );
}

function DemoSection({ icon: Icon, title, description, color, children }) {
  return (
    <Card className="mb-6">
      <div className="p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className={`p-2 rounded-lg bg-${color}-100`}>
            <Icon size={20} className={`text-${color}-600`} />
          </div>
          <div>
            <h3 className="font-bold text-gray-900 text-lg">{title}</h3>
            <p className="text-sm text-gray-500">{description}</p>
          </div>
        </div>
        <div className="mt-4">{children}</div>
      </div>
    </Card>
  );
}

export default function AcidDemoPage() {
  const [accounts, setAccounts] = useState([]);
  const [results, setResults] = useState({});
  const [loading, setLoading] = useState({});

  useEffect(() => { getAcidAccounts().then(setAccounts).catch(() => {}); }, []);

  // Forms
  const [atomForm, setAtomForm] = useState({ from: '', to: '', amount: 1000, inject: false });
  const [consForm, setConsForm] = useState({ account: '', amount: 999999, test: 'negative_balance' });
  const [isoForm, setIsoForm] = useState({ account: '', amount: 500 });
  const [durForm, setDurForm] = useState({ account: '', amount: 100 });

  const run = async (key, fn, payload) => {
    setLoading(l => ({ ...l, [key]: true }));
    setResults(r => ({ ...r, [key]: null }));
    try {
      const data = await fn(payload);
      setResults(r => ({ ...r, [key]: data }));
    } catch (e) {
      setResults(r => ({ ...r, [key]: { success: false, outcome: 'NETWORK_ERROR', log: [{ step: 'ERROR', detail: e.message }] } }));
    }
    setLoading(l => ({ ...l, [key]: false }));
  };

  const acctOptions = accounts.map(a => (
    <option key={a.account_id} value={a.account_id}>
      #{a.account_id} — {a.customer_name} ({a.account_type}) — ₹{Number(a.current_balance).toLocaleString('en-IN')}
    </option>
  ));

  return (
    <>
      <PageHeader title="ACID Properties Demo" subtitle="Interactive demonstration of database transaction guarantees" />

      <div className="mb-6 p-4 bg-indigo-50 rounded-lg text-sm text-indigo-800">
        <strong>ACID</strong> stands for <strong>Atomicity</strong>, <strong>Consistency</strong>, <strong>Isolation</strong>, and <strong>Durability</strong> — the four guarantees that PostgreSQL provides for every transaction. Each demo below runs real SQL transactions against the bank database so you can observe these properties in action.
      </div>

      {/* ── ATOMICITY ── */}
      <DemoSection icon={Atom} title="Atomicity" description="All-or-nothing: a transfer either fully completes or fully rolls back." color="blue">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
          <FormField label="From Account">
            <Select value={atomForm.from} onChange={e => setAtomForm(f => ({ ...f, from: e.target.value }))}>
              <option value="">Select source…</option>
              {acctOptions}
            </Select>
          </FormField>
          <FormField label="To Account">
            <Select value={atomForm.to} onChange={e => setAtomForm(f => ({ ...f, to: e.target.value }))}>
              <option value="">Select destination…</option>
              {acctOptions}
            </Select>
          </FormField>
          <FormField label="Amount (₹)">
            <Input type="number" value={atomForm.amount} onChange={e => setAtomForm(f => ({ ...f, amount: +e.target.value }))} />
          </FormField>
        </div>
        <div className="flex items-center gap-4 mb-3">
          <label className="flex items-center gap-2 text-sm cursor-pointer">
            <input type="checkbox" checked={atomForm.inject} onChange={e => setAtomForm(f => ({ ...f, inject: e.target.checked }))} className="accent-red-500" />
            <span className="text-red-600 font-medium">Inject failure after debit (simulate crash)</span>
          </label>
        </div>
        <div className="flex gap-2">
          <Btn onClick={() => run('atomicity', acidAtomicity, {
            from_account_id: +atomForm.from, to_account_id: +atomForm.to,
            amount: atomForm.amount, inject_failure: atomForm.inject
          })} disabled={loading.atomicity || !atomForm.from || !atomForm.to}>
            <Play size={14} className="inline mr-1" />{loading.atomicity ? 'Running…' : 'Run Transfer'}
          </Btn>
          <Btn variant="secondary" onClick={() => { setResults(r => ({ ...r, atomicity: null })); getAcidAccounts().then(setAccounts); }}>
            <RotateCcw size={14} className="inline mr-1" />Refresh
          </Btn>
        </div>
        {results.atomicity && (
          <div className={`mt-3 p-3 rounded-lg text-sm font-semibold ${results.atomicity.success ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'}`}>
            Outcome: {results.atomicity.outcome} — {results.atomicity.success ? 'Both accounts updated atomically' : 'No account was changed (rolled back)'}
          </div>
        )}
        <LogViewer log={results.atomicity?.log} />
      </DemoSection>

      {/* ── CONSISTENCY ── */}
      <DemoSection icon={ShieldCheck} title="Consistency" description="Constraints are always enforced — invalid data is never written." color="emerald">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
          <FormField label="Account">
            <Select value={consForm.account} onChange={e => setConsForm(f => ({ ...f, account: e.target.value }))}>
              <option value="">Select account…</option>
              {acctOptions}
            </Select>
          </FormField>
          <FormField label="Amount (₹)">
            <Input type="number" value={consForm.amount} onChange={e => setConsForm(f => ({ ...f, amount: +e.target.value }))} />
          </FormField>
          <FormField label="Test Type">
            <Select value={consForm.test} onChange={e => setConsForm(f => ({ ...f, test: e.target.value }))}>
              <option value="negative_balance">Overdraw (violate min balance)</option>
              <option value="fk_violation">FK violation (fake account)</option>
            </Select>
          </FormField>
        </div>
        <Btn onClick={() => run('consistency', acidConsistency, {
          account_id: +consForm.account, amount: consForm.amount, test_type: consForm.test
        })} disabled={loading.consistency || !consForm.account}>
          <Play size={14} className="inline mr-1" />{loading.consistency ? 'Running…' : 'Run Consistency Test'}
        </Btn>
        {results.consistency && (
          <div className={`mt-3 p-3 rounded-lg text-sm font-semibold ${results.consistency.success ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'}`}>
            Outcome: {results.consistency.outcome} — {results.consistency.success ? 'Operation succeeded (within constraints)' : 'Constraint violation caught — database stays consistent'}
          </div>
        )}
        <LogViewer log={results.consistency?.log} />
      </DemoSection>

      {/* ── ISOLATION ── */}
      <DemoSection icon={Layers} title="Isolation" description="Concurrent transactions don't see each other's uncommitted changes." color="violet">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
          <FormField label="Account">
            <Select value={isoForm.account} onChange={e => setIsoForm(f => ({ ...f, account: e.target.value }))}>
              <option value="">Select account…</option>
              {acctOptions}
            </Select>
          </FormField>
          <FormField label="Debit Amount (₹)">
            <Input type="number" value={isoForm.amount} onChange={e => setIsoForm(f => ({ ...f, amount: +e.target.value }))} />
          </FormField>
        </div>
        <p className="text-xs text-gray-500 mb-3">
          Two transactions run concurrently: Txn A debits the account; Txn B reads the balance before and after A commits.
          Under READ COMMITTED isolation, B sees the old value until A commits.
        </p>
        <Btn onClick={() => run('isolation', acidIsolation, {
          account_id: +isoForm.account, amount: isoForm.amount
        })} disabled={loading.isolation || !isoForm.account}>
          <Play size={14} className="inline mr-1" />{loading.isolation ? 'Running…' : 'Run Isolation Demo'}
        </Btn>
        {results.isolation && (
          <div className="mt-3 p-3 rounded-lg text-sm font-semibold bg-violet-50 text-violet-800">
            Outcome: {results.isolation.outcome} — Txn B could not see Txn A's uncommitted changes (READ COMMITTED)
          </div>
        )}
        <LogViewer log={results.isolation?.log} />
      </DemoSection>

      {/* ── DURABILITY ── */}
      <DemoSection icon={HardDrive} title="Durability" description="Once committed, data survives crashes — thanks to PostgreSQL's Write-Ahead Log (WAL)." color="amber">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
          <FormField label="Account">
            <Select value={durForm.account} onChange={e => setDurForm(f => ({ ...f, account: e.target.value }))}>
              <option value="">Select account…</option>
              {acctOptions}
            </Select>
          </FormField>
          <FormField label="Deposit Amount (₹)">
            <Input type="number" value={durForm.amount} onChange={e => setDurForm(f => ({ ...f, amount: +e.target.value }))} />
          </FormField>
        </div>
        <p className="text-xs text-gray-500 mb-3">
          A deposit is committed, then immediately re-read. PostgreSQL flushes to the WAL before acknowledging COMMIT, so even a power loss after COMMIT cannot lose this data.
        </p>
        <Btn onClick={() => run('durability', acidDurability, {
          account_id: +durForm.account, amount: durForm.amount
        })} disabled={loading.durability || !durForm.account}>
          <Play size={14} className="inline mr-1" />{loading.durability ? 'Running…' : 'Run Durability Demo'}
        </Btn>
        {results.durability && (
          <div className="mt-3 p-3 rounded-lg text-sm font-semibold bg-green-50 text-green-800">
            Outcome: {results.durability.outcome} — Data written to WAL and persisted
          </div>
        )}
        <LogViewer log={results.durability?.log} />
      </DemoSection>
    </>
  );
}
