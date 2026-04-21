import { useState, useRef } from 'react';
import { searchAll } from '../api';
import { PageHeader, Card, Badge, Spinner, ErrorBox } from '../components/UI';
import {
  Search, Users, CreditCard, Receipt, Landmark, Briefcase, Building2
} from 'lucide-react';

const sectionMeta = {
  customers:    { icon: Users,      label: 'Customers',    color: 'indigo' },
  accounts:     { icon: CreditCard, label: 'Accounts',     color: 'emerald' },
  transactions: { icon: Receipt,    label: 'Transactions', color: 'amber' },
  loans:        { icon: Landmark,   label: 'Loans',        color: 'rose' },
  employees:    { icon: Briefcase,  label: 'Employees',    color: 'sky' },
  branches:     { icon: Building2,  label: 'Branches',     color: 'violet' },
};

function highlight(text, q) {
  if (!text || !q) return text;
  const str = String(text);
  const idx = str.toLowerCase().indexOf(q.toLowerCase());
  if (idx === -1) return str;
  return (
    <>
      {str.slice(0, idx)}
      <mark className="bg-yellow-200 rounded px-0.5">{str.slice(idx, idx + q.length)}</mark>
      {str.slice(idx + q.length)}
    </>
  );
}

function fmt(n) {
  return Number(n).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function ResultSection({ sectionKey, rows, q }) {
  const meta = sectionMeta[sectionKey];
  if (!rows || rows.length === 0) return null;
  const Icon = meta.icon;

  return (
    <Card>
      <div className="flex items-center gap-2 mb-3">
        <Icon size={18} className={`text-${meta.color}-600`} />
        <h3 className="font-semibold text-gray-800">{meta.label}</h3>
        <Badge color={meta.color}>{rows.length}{rows.length === 50 ? '+' : ''}</Badge>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="border-b border-gray-200 text-left text-xs text-gray-500 uppercase tracking-wider">
              {sectionKey === 'customers' && (
                <><th className="px-3 py-2">ID</th><th className="px-3 py-2">Name</th><th className="px-3 py-2">Phone</th><th className="px-3 py-2">Email</th><th className="px-3 py-2">Occupation</th><th className="px-3 py-2">Status</th></>
              )}
              {sectionKey === 'accounts' && (
                <><th className="px-3 py-2">Acct #</th><th className="px-3 py-2">Customer</th><th className="px-3 py-2">Type</th><th className="px-3 py-2 text-right">Balance</th><th className="px-3 py-2">Status</th></>
              )}
              {sectionKey === 'transactions' && (
                <><th className="px-3 py-2">Ref #</th><th className="px-3 py-2">Account</th><th className="px-3 py-2">Type</th><th className="px-3 py-2">Channel</th><th className="px-3 py-2 text-right">Amount</th><th className="px-3 py-2">Description</th></>
              )}
              {sectionKey === 'loans' && (
                <><th className="px-3 py-2">ID</th><th className="px-3 py-2">Customer</th><th className="px-3 py-2">Type</th><th className="px-3 py-2 text-right">Amount</th><th className="px-3 py-2">App Status</th><th className="px-3 py-2">Status</th></>
              )}
              {sectionKey === 'employees' && (
                <><th className="px-3 py-2">ID</th><th className="px-3 py-2">Name</th><th className="px-3 py-2">Designation</th><th className="px-3 py-2">Status</th></>
              )}
              {sectionKey === 'branches' && (
                <><th className="px-3 py-2">ID</th><th className="px-3 py-2">Branch</th><th className="px-3 py-2">City</th><th className="px-3 py-2">IFSC</th></>
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {rows.map((r, i) => (
              <tr key={i} className="hover:bg-gray-50 transition-colors">
                {sectionKey === 'customers' && (
                  <><td className="px-3 py-2 text-gray-500">{r.customer_id}</td><td className="px-3 py-2 font-medium">{highlight(r.full_name, q)}</td><td className="px-3 py-2">{highlight(r.phone, q)}</td><td className="px-3 py-2 text-gray-500">{highlight(r.email, q)}</td><td className="px-3 py-2">{highlight(r.occupation, q)}</td><td className="px-3 py-2"><Badge color={r.status === 'active' ? 'green' : 'red'}>{r.status}</Badge></td></>
                )}
                {sectionKey === 'accounts' && (
                  <><td className="px-3 py-2 font-mono text-xs">{highlight(r.account_number, q)}</td><td className="px-3 py-2 font-medium">{highlight(r.customer_name, q)}</td><td className="px-3 py-2 capitalize">{r.account_type}</td><td className="px-3 py-2 text-right font-mono">₹{fmt(r.current_balance)}</td><td className="px-3 py-2"><Badge color={r.status === 'active' ? 'green' : 'red'}>{r.status}</Badge></td></>
                )}
                {sectionKey === 'transactions' && (
                  <><td className="px-3 py-2 font-mono text-xs">{highlight(r.reference_number, q)}</td><td className="px-3 py-2 font-mono text-xs">{highlight(r.account_number, q)}</td><td className="px-3 py-2"><Badge color={r.txn_type === 'credit' ? 'green' : 'red'}>{r.txn_type}</Badge></td><td className="px-3 py-2 capitalize">{highlight(r.channel, q)}</td><td className="px-3 py-2 text-right font-mono">₹{fmt(r.amount)}</td><td className="px-3 py-2 text-gray-600 truncate max-w-[200px]">{highlight(r.description, q)}</td></>
                )}
                {sectionKey === 'loans' && (
                  <><td className="px-3 py-2 text-gray-500">{r.loan_id}</td><td className="px-3 py-2 font-medium">{highlight(r.customer_name, q)}</td><td className="px-3 py-2 capitalize">{highlight(r.loan_type, q)}</td><td className="px-3 py-2 text-right font-mono">₹{fmt(r.applied_amount)}</td><td className="px-3 py-2"><Badge color={r.application_status === 'disbursed' ? 'green' : r.application_status === 'rejected' ? 'red' : 'amber'}>{highlight(r.application_status, q)}</Badge></td><td className="px-3 py-2"><Badge color={r.status === 'active' ? 'green' : 'gray'}>{r.status}</Badge></td></>
                )}
                {sectionKey === 'employees' && (
                  <><td className="px-3 py-2 text-gray-500">{r.emp_id}</td><td className="px-3 py-2 font-medium">{highlight(r.full_name, q)}</td><td className="px-3 py-2">{highlight(r.designation, q)}</td><td className="px-3 py-2"><Badge color={r.status === 'active' ? 'green' : 'red'}>{r.status}</Badge></td></>
                )}
                {sectionKey === 'branches' && (
                  <><td className="px-3 py-2 text-gray-500">{r.branch_id}</td><td className="px-3 py-2 font-medium">{highlight(r.branch_name, q)}</td><td className="px-3 py-2">{highlight(r.city, q)}</td><td className="px-3 py-2 font-mono text-xs">{highlight(r.ifsc_code, q)}</td></>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

export default function SearchPage() {
  const [q, setQ] = useState('');
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const timer = useRef(null);

  const doSearch = async (term) => {
    if (!term.trim()) { setResults(null); return; }
    setLoading(true);
    setError(null);
    try {
      const data = await searchAll(term.trim());
      setResults(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e) => {
    const val = e.target.value;
    setQ(val);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => doSearch(val), 350);
  };

  const totalResults = results
    ? Object.values(results).reduce((s, arr) => s + arr.length, 0)
    : 0;

  return (
    <>
      <PageHeader title="Global Search" subtitle="Search across all banking records" />

      {/* Search input */}
      <Card>
        <div className="relative">
          <Search size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={q}
            onChange={handleChange}
            placeholder="Search customers, accounts, transactions, loans, employees, branches..."
            className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg text-sm
                       focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            autoFocus
          />
        </div>
        {results && !loading && (
          <p className="mt-2 text-xs text-gray-500">
            Found <strong>{totalResults}</strong> result{totalResults !== 1 ? 's' : ''} across {Object.values(results).filter(a => a.length > 0).length} categories
          </p>
        )}
      </Card>

      {loading && <Spinner />}
      {error && <ErrorBox message={error} />}

      {results && !loading && totalResults === 0 && q.trim() && (
        <Card>
          <p className="text-center text-gray-500 py-8">No results found for &ldquo;{q}&rdquo;</p>
        </Card>
      )}

      {results && !loading && (
        <div className="space-y-4 mt-2">
          {Object.keys(sectionMeta).map((key) => (
            <ResultSection key={key} sectionKey={key} rows={results[key]} q={q} />
          ))}
        </div>
      )}
    </>
  );
}
