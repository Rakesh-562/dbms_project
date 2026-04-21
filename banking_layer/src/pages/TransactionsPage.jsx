import { useState, useMemo } from 'react';
import { useApi } from '../hooks';
import { getTransactions, createTransaction, getAccounts, getEmployees } from '../api';
import { PageHeader, Card, DataTable, Badge, Spinner, ErrorBox, Modal, FormField, Input, Select, Btn } from '../components/UI';
import { Search } from 'lucide-react';

const columns = [
  { key: 'txn_id',           label: 'ID' },
  { key: 'account_number',   label: 'Account' },
  { key: 'txn_type',         label: 'Type', render: (r) =>
    <Badge variant={r.txn_type === 'credit' ? 'green' : 'red'}>{r.txn_type}</Badge> },
  { key: 'channel',          label: 'Channel', render: (r) => <Badge variant="blue">{r.channel}</Badge> },
  { key: 'amount',           label: 'Amount', render: (r) => `₹${Number(r.amount).toLocaleString('en-IN')}` },
  { key: 'balance_after',    label: 'Balance After', render: (r) => `₹${Number(r.balance_after).toLocaleString('en-IN')}` },
  { key: 'reference_number', label: 'Reference' },
  { key: 'txn_date',         label: 'Date', render: (r) => new Date(r.txn_date).toLocaleString() },
  { key: 'description',      label: 'Description' },
];

const empty = { account_id: '', txn_type: 'credit', channel: 'branch', amount: '', description: '', initiated_by: '' };

export default function TransactionsPage() {
  const { data, loading, error, refetch } = useApi(getTransactions);
  const accounts = useApi(getAccounts);
  const employees = useApi(getEmployees);
  const [modal, setModal] = useState(false);
  const [form, setForm] = useState(empty);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState(null);
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    if (!data || !search.trim()) return data || [];
    const q = search.toLowerCase();
    return data.filter(r => [r.account_number, r.reference_number, r.description, r.txn_type, r.channel].some(v => v && String(v).toLowerCase().includes(q)));
  }, [data, search]);

  const openAdd = () => { setForm(empty); setFormError(null); setModal(true); };
  const close = () => { setModal(false); setFormError(null); };
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const save = async () => {
    setSaving(true); setFormError(null);
    try {
      await createTransaction(form);
      close(); refetch();
    } catch (e) { setFormError(e.message || 'Save failed'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  return (
    <>
      <PageHeader title="Transactions" subtitle={`${data.length} records`}>
        <Btn onClick={openAdd}>+ New Transaction</Btn>
      </PageHeader>
      <div className="relative mb-4">
        <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input type="text" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search by reference, account, description, type, channel..." className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
      </div>
      <Card><DataTable columns={columns} rows={filtered} /></Card>

      <Modal open={modal} onClose={close} title="New Transaction">
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Account">
            <Select value={form.account_id} onChange={e => set('account_id', e.target.value)}>
              <option value="">Select</option>
              {(accounts.data || []).map(a => <option key={a.account_id} value={a.account_id}>{a.account_number} — {a.customer_name}</option>)}
            </Select>
          </FormField>
          <FormField label="Type">
            <Select value={form.txn_type} onChange={e => set('txn_type', e.target.value)}>
              <option value="credit">Credit</option><option value="debit">Debit</option>
            </Select>
          </FormField>
          <FormField label="Channel">
            <Select value={form.channel} onChange={e => set('channel', e.target.value)}>
              {['branch','atm','upi','neft','rtgs','imps','online','pos'].map(v => <option key={v} value={v}>{v.toUpperCase()}</option>)}
            </Select>
          </FormField>
          <FormField label="Amount"><Input type="number" step="0.01" value={form.amount} onChange={e => set('amount', e.target.value)} /></FormField>
          <FormField label="Description" className="col-span-2"><Input value={form.description} onChange={e => set('description', e.target.value)} /></FormField>
          <FormField label="Initiated By">
            <Select value={form.initiated_by} onChange={e => set('initiated_by', e.target.value)}>
              <option value="">System</option>
              {(employees.data || []).map(e => <option key={e.emp_id} value={e.emp_id}>{e.full_name}</option>)}
            </Select>
          </FormField>
        </div>
        {formError && <div className="mt-3 p-3 bg-red-50 text-red-700 rounded-lg text-sm">{formError}</div>}
        <div className="flex justify-end gap-2 mt-4">
          <Btn variant="secondary" onClick={close}>Cancel</Btn>
          <Btn onClick={save} disabled={saving}>{saving ? 'Saving...' : 'Save'}</Btn>
        </div>
      </Modal>
    </>
  );
}
