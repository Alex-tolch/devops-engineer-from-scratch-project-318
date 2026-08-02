import type { ReactNode } from "react";
import { Layout as RALayout } from "react-admin";

export const Layout = ({ children }: { children: ReactNode }) => (
  <RALayout>{children}</RALayout>
);
