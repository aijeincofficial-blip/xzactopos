import { beforeAll, describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { Package } from "lucide-react";
import { initI18n } from "../i18n/index.ts";
import { DataTable, EmptyState, LimeButton, MoneyText, Pill, Receipt, Segmented, StatTile, SyncChip } from "./index.ts";

beforeAll(async () => {
  await initI18n("en");
});

describe("night-market UI kit (UI-01)", () => {
  it("formats money via @pos/core Intl formatting with tabular-nums and total variant", () => {
    const lineHtml = renderToStaticMarkup(<MoneyText minor={125000} currency="PHP" />);
    expect(lineHtml).toContain("1,250.00");
    expect(lineHtml).toContain("tabular-nums");

    const totalHtml = renderToStaticMarkup(<MoneyText minor={35500} currency="PHP" variant="total" />);
    expect(totalHtml).toContain("355.00");
    expect(totalHtml).toContain("font-display");
  });

  it("renders all 4 SyncChip states clearly", () => {
    expect(renderToStaticMarkup(<SyncChip state="synced" />)).toContain("Synced");
    expect(renderToStaticMarkup(<SyncChip state="offline" queuedCount={3} />)).toContain("Offline · 3 queued");
    expect(renderToStaticMarkup(<SyncChip state="syncing" />)).toContain("Syncing");
    expect(renderToStaticMarkup(<SyncChip state="error" />)).toContain("Sync issue");
  });

  it("renders Receipt zig-zag card, LimeButton, Pill, Segmented, DataTable, StatTile, and EmptyState", () => {
    const html = renderToStaticMarkup(
      <div>
        <LimeButton>Charge</LimeButton>
        <Pill active count={4}>Coffee</Pill>
        <Segmented
          value="a"
          onChange={() => undefined}
          options={[
            { value: "a", label: "One" },
            { value: "b", label: "Two" },
          ]}
        />
        <Receipt>Ticket</Receipt>
        <StatTile eyebrow="TOTAL" value="42" />
        <DataTable
          columns={[{ key: "name", header: "Item", render: (r: { name: string }) => r.name }]}
          rows={[{ name: "Barako" }]}
          rowKey={(r) => r.name}
        />
        <EmptyState icon={Package} message="Nothing yet" actionLabel="Add item" onAction={() => undefined} />
      </div>,
    );
    expect(html).toContain("Charge");
    expect(html).toContain("Coffee");
    expect(html).toContain("Barako");
    expect(html).toContain("receipt");
    expect(html).toContain("Nothing yet");
  });
});
